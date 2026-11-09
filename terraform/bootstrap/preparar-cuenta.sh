#!/usr/bin/env bash
# Prepara la cuenta AWS (UNA sola vez) para que GitHub Actions pueda ejecutar los pipelines
# SIN guardar claves de acceso:
#   1. Bucket S3 para el estado remoto de Terraform (versionado, cifrado, privado)
#   2. Proveedor OIDC de GitHub (token.actions.githubusercontent.com)
#   3. Rol IAM "github-actions-<proyecto>" que SOLO puede asumir tu repositorio
#
# Uso (en AWS CloudShell o con AWS CLI configurado como administrador):
#   bash preparar-cuenta.sh <usuario-github>/<repositorio> [region] [proyecto]
# Ejemplo:
#   bash preparar-cuenta.sh EJGC18/proyecto-final-devops us-east-1 tareas-devops
set -euo pipefail

REPO="${1:?Indica el repositorio: usuario/repositorio}"
REGION="${2:-us-east-1}"
PROJECT="${3:-tareas-devops}"

if [[ ! "$REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
  echo "Formato inválido. Usa usuario/repositorio (ej. EJGC18/proyecto-final-devops)"; exit 1
fi

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="tfstate-${PROJECT}-${ACCOUNT_ID}"
ROLE_NAME="github-actions-${PROJECT}"
OIDC_URL="token.actions.githubusercontent.com"
OIDC_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_URL}"

echo "Cuenta: ${ACCOUNT_ID} | Región: ${REGION} | Repo: ${REPO}"
echo

# ---------- 1. Bucket del estado de Terraform ----------
if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "[1/3] Bucket ${BUCKET} ya existe"
else
  if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" >/dev/null
  else
    aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
      --create-bucket-configuration LocationConstraint="$REGION" >/dev/null
  fi
  echo "[1/3] Bucket ${BUCKET} creado"
fi
aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled
aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# ---------- 2. Proveedor OIDC de GitHub ----------
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN" >/dev/null 2>&1; then
  echo "[2/3] Proveedor OIDC de GitHub ya existe"
else
  aws iam create-open-id-connect-provider \
    --url "https://${OIDC_URL}" \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 >/dev/null
  echo "[2/3] Proveedor OIDC de GitHub creado"
fi

# ---------- 3. Rol para GitHub Actions ----------
# Confianza: solo tokens emitidos por GitHub para ESTE repositorio.
# GitHub puede enviar el "sub" en dos formatos:
#   repo:usuario/repo:ref:...                     (clásico)
#   repo:usuario@<id>/repo@<id>:ref:...           (con IDs inmutables)
# "@" no es válido en nombres de GitHub, así que el comodín no abre la puerta a otros repos.
OWNER="${REPO%%/*}"
NAME="${REPO##*/}"
cat > /tmp/trust.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Federated": "${OIDC_ARN}" },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": { "${OIDC_URL}:aud": "sts.amazonaws.com" },
      "StringLike":   { "${OIDC_URL}:sub": ["repo:${REPO}:*", "repo:${OWNER}@*/${NAME}@*:*"] }
    }
  }]
}
EOF

if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  aws iam update-assume-role-policy --role-name "$ROLE_NAME" --policy-document file:///tmp/trust.json
  echo "[3/3] Rol ${ROLE_NAME} ya existía: confianza actualizada para ${REPO}"
else
  aws iam create-role --role-name "$ROLE_NAME" \
    --assume-role-policy-document file:///tmp/trust.json \
    --description "Rol que asume GitHub Actions (${REPO}) para los pipelines" \
    --max-session-duration 3600 >/dev/null
  echo "[3/3] Rol ${ROLE_NAME} creado"
fi

# Permisos de los servicios que gestiona el proyecto
for POL in AmazonEC2FullAccess ElasticLoadBalancingFullAccess AmazonEC2ContainerRegistryFullAccess \
           AmazonECS_FullAccess CloudWatchLogsFullAccess; do
  aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn "arn:aws:iam::aws:policy/${POL}"
done

# Permisos acotados: IAM solo sobre roles del proyecto y S3 solo sobre el bucket del estado
cat > /tmp/acotada.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "RolesDelProyecto",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:PassRole", "iam:TagRole", "iam:UntagRole",
        "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:ListRolePolicies",
        "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole", "iam:UpdateAssumeRolePolicy"
      ],
      "Resource": "arn:aws:iam::${ACCOUNT_ID}:role/${PROJECT}-*"
    },
    {
      "Sid": "RolesVinculadosAServicios",
      "Effect": "Allow",
      "Action": "iam:CreateServiceLinkedRole",
      "Resource": "*",
      "Condition": { "StringLike": { "iam:AWSServiceName": ["ecs.amazonaws.com", "elasticloadbalancing.amazonaws.com"] } }
    },
    {
      "Sid": "EstadoTerraform",
      "Effect": "Allow",
      "Action": ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": ["arn:aws:s3:::${BUCKET}", "arn:aws:s3:::${BUCKET}/*"]
    }
  ]
}
EOF
aws iam put-role-policy --role-name "$ROLE_NAME" --policy-name permisos-acotados \
  --policy-document file:///tmp/acotada.json

ROLE_ARN="$(aws iam get-role --role-name "$ROLE_NAME" --query Role.Arn --output text)"

echo
echo "=================================================================="
echo " Listo. Crea estas VARIABLES en GitHub (Settings > Secrets and"
echo " variables > Actions > pestaña Variables):"
echo
echo "   AWS_ROLE_ARN     = ${ROLE_ARN}"
echo "   TF_STATE_BUCKET  = ${BUCKET}"
echo "   AWS_REGION       = ${REGION}"
echo
echo " No hace falta crear ningún secret: GitHub usa OIDC."
echo "=================================================================="
