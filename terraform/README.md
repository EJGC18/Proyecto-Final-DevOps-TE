# terraform/ — Infraestructura como código

| Archivo | Qué crea |
|---|---|
| `network.tf` | VPC 10.0.0.0/16, 2 subredes públicas (2 AZ), Internet Gateway, tabla de rutas |
| `security.tf` | SG del ALB (80 desde Internet) y SG de ECS (solo desde el ALB) |
| `alb.tf` | Application Load Balancer, 2 target groups, regla `/api/*` → backend |
| `ecr.tf` | Repositorios ECR `frontend` y `backend` (escaneo al subir, retención de 10 imágenes) |
| `ecs.tf` | Cluster ECS, logs de CloudWatch, task definitions y servicios Fargate con circuit breaker |
| `iam.tf` | Rol de ejecución (ECR + logs) y rol de tarea de ECS |
| `outputs.tf` | URL de la app, URLs de ECR, nombres de cluster y servicios |

## Ejecución local (alternativa al Pipeline 1)

```bash
# 1. Una sola vez: bucket del estado + OIDC + rol del CI
./bootstrap/preparar-cuenta.sh <usuario>/<repo> us-east-1

# 2. Configuración
cp backend.hcl.example backend.hcl            # pon el nombre del bucket
cp terraform.tfvars.example terraform.tfvars  # ajusta si hace falta

# 3. Aplicar
terraform init -backend-config=backend.hcl
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan

# 4. Ver salidas
terraform output app_url

# 5. Eliminar todo al terminar
terraform destroy
```

> El estado local y el del pipeline son el **mismo** (bucket S3), así que puedes alternar entre ambos sin duplicar recursos.
> Nota: tras el primer `apply`, los servicios ECS intentarán arrancar con la imagen `latest` que todavía no existe; es normal hasta que corran los Pipelines 2 y 3.
