#!/usr/bin/env bash
# Pipeline 2: construye la imagen de un componente, la etiqueta y la publica en ECR.
# Uso: build-push.sh <frontend|backend> <tag>
# Requiere: AWS_REGION, PROJECT y sesión de Docker iniciada en ECR.
set -euo pipefail

COMPONENTE="${1:?Indica el componente: frontend o backend}"
TAG="${2:?Indica el tag (ej. SHA corto del commit)}"
: "${AWS_REGION:?Falta AWS_REGION}"
: "${PROJECT:?Falta PROJECT}"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
REPO="${REGISTRY}/${PROJECT}/${COMPONENTE}"
CONTEXTO="aplicacion/${COMPONENTE}"

# Espera hasta 10 min a que exista el repositorio (en el primer push el Pipeline 1
# corre en paralelo). Si no aparece, falla con un mensaje claro.
for i in $(seq 1 40); do
  aws ecr describe-repositories --repository-names "${PROJECT}/${COMPONENTE}" >/dev/null 2>&1 && break
  if [ "$i" -eq 40 ]; then
    echo "::error::No existe el repositorio ECR ${PROJECT}/${COMPONENTE}. Ejecuta primero el Pipeline 1 (Terraform)."
    exit 1
  fi
  echo "Esperando a que Terraform cree el repositorio ECR (${i}/40)..."
  sleep 15
done

echo "==> Construyendo ${COMPONENTE} (${TAG})"
docker build \
  --platform linux/amd64 \
  --build-arg APP_VERSION="${TAG}" \
  --label org.opencontainers.image.revision="${GITHUB_SHA:-local}" \
  -t "${REPO}:${TAG}" \
  -t "${REPO}:latest" \
  "${CONTEXTO}"

echo "==> Publicando en ${REPO}"
docker push "${REPO}:${TAG}"
docker push "${REPO}:latest"

# Evidencia: la imagen quedó registrada en ECR
aws ecr describe-images \
  --repository-name "${PROJECT}/${COMPONENTE}" \
  --image-ids imageTag="${TAG}" \
  --query 'imageDetails[0].{tags:imageTags,digest:imageDigest,pushedAt:imagePushedAt,sizeBytes:imageSizeInBytes}' \
  --output table

echo "image=${REPO}:${TAG}" >> "${GITHUB_OUTPUT:-/dev/null}"
