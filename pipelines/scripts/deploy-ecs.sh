#!/usr/bin/env bash
# Pipeline 3: registra una nueva revisión de la task definition con la imagen indicada,
# actualiza el servicio ECS y espera a que quede estable. Si falla, hace rollback.
# Uso: deploy-ecs.sh <frontend|backend> <tag>
# Requiere: AWS_REGION, PROJECT
set -euo pipefail

COMPONENTE="${1:?Indica el componente: frontend o backend}"
TAG="${2:?Indica el tag de la imagen}"
: "${AWS_REGION:?Falta AWS_REGION}"
: "${PROJECT:?Falta PROJECT}"

CLUSTER="${PROJECT}-cluster"
SERVICIO="${PROJECT}-${COMPONENTE}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
IMAGEN="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT}/${COMPONENTE}:${TAG}"

# 1) Verificar que la imagen existe en ECR antes de tocar el servicio
if ! aws ecr describe-images --repository-name "${PROJECT}/${COMPONENTE}" \
     --image-ids imageTag="${TAG}" >/dev/null 2>&1; then
  echo "::error::La imagen ${IMAGEN} no existe en ECR. Ejecuta el Pipeline 2 primero."
  exit 1
fi

# 2) Task definition actual del servicio (para basarnos en ella y para un posible rollback)
#    Espera hasta 10 min por si Terraform todavía está creando el servicio (primer despliegue)
for i in $(seq 1 40); do
  TD_ANTERIOR="$(aws ecs describe-services --cluster "$CLUSTER" --services "$SERVICIO" \
    --query 'services[?status==`ACTIVE`].taskDefinition | [0]' --output text 2>/dev/null || true)"
  [ -n "$TD_ANTERIOR" ] && [ "$TD_ANTERIOR" != "None" ] && break
  if [ "$i" -eq 40 ]; then
    echo "::error::No se encontró el servicio ${SERVICIO} en ${CLUSTER}. ¿Se ejecutó el Pipeline 1?"
    exit 1
  fi
  echo "Esperando a que exista el servicio ${SERVICIO} (${i}/40)..."
  sleep 15
done
echo "Task definition actual: $TD_ANTERIOR"
echo "previous_${COMPONENTE}=${TD_ANTERIOR}" >> "${GITHUB_OUTPUT:-/dev/null}"

# 3) Nueva revisión: misma configuración, solo cambia la imagen
aws ecs describe-task-definition --task-definition "$TD_ANTERIOR" --query taskDefinition \
  | jq --arg IMG "$IMAGEN" --arg NAME "$COMPONENTE" '
      .containerDefinitions |= map(if .name == $NAME then .image = $IMG else . end)
      | del(.taskDefinitionArn, .revision, .status, .requiresAttributes,
            .compatibilities, .registeredAt, .registeredBy, .deregisteredAt)' \
  > /tmp/taskdef-${COMPONENTE}.json

TD_NUEVA="$(aws ecs register-task-definition \
  --cli-input-json "file:///tmp/taskdef-${COMPONENTE}.json" \
  --query 'taskDefinition.taskDefinitionArn' --output text)"
echo "Nueva task definition: $TD_NUEVA"

# 4) Actualizar el servicio (rolling update; el circuit breaker de ECS vigila la salud)
aws ecs update-service --cluster "$CLUSTER" --service "$SERVICIO" \
  --task-definition "$TD_NUEVA" --force-new-deployment \
  --query 'service.deployments[0].{id:id,estado:rolloutState}' --output table

# 5) Esperar estabilidad (máx. ~10 min). Si falla -> rollback explícito
echo "Esperando a que ${SERVICIO} quede estable..."
if aws ecs wait services-stable --cluster "$CLUSTER" --services "$SERVICIO"; then
  ESTADO="$(aws ecs describe-services --cluster "$CLUSTER" --services "$SERVICIO" \
    --query 'services[0].deployments[?status==`PRIMARY`].rolloutState | [0]' --output text)"
  TD_ACTIVA="$(aws ecs describe-services --cluster "$CLUSTER" --services "$SERVICIO" \
    --query 'services[0].taskDefinition' --output text)"
  if [ "$TD_ACTIVA" != "$TD_NUEVA" ] || [ "$ESTADO" = "FAILED" ]; then
    echo "::error::El circuit breaker de ECS revirtió el despliegue de ${COMPONENTE} (estado: $ESTADO)."
    exit 1
  fi
  echo "✅ ${SERVICIO} desplegado con ${IMAGEN}"
else
  echo "::error::${SERVICIO} no se estabilizó. Haciendo rollback a ${TD_ANTERIOR}"
  aws ecs update-service --cluster "$CLUSTER" --service "$SERVICIO" \
    --task-definition "$TD_ANTERIOR" >/dev/null
  # Muestra el motivo para diagnosticar (eventos recientes del servicio)
  aws ecs describe-services --cluster "$CLUSTER" --services "$SERVICIO" \
    --query 'services[0].events[0:5].message' --output text || true
  exit 1
fi
