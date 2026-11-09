locals {
  componentes = toset(["frontend", "backend"])
}

resource "aws_ecr_repository" "app" {
  for_each = local.componentes

  name = "${var.project}/${each.key}"
  # permite mover el tag "latest"; cada build también usa el SHA (inmutable en la práctica)
  image_tag_mutability = "MUTABLE"
  # permite "terraform destroy" aunque haya imágenes
  force_delete = true

  image_scanning_configuration {
    # escaneo de vulnerabilidades en cada push
    scan_on_push = true
  }
}

# Conserva solo las últimas 10 imágenes para no acumular costo de almacenamiento
resource "aws_ecr_lifecycle_policy" "app" {
  for_each   = aws_ecr_repository.app
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Conservar las ultimas 10 imagenes"
      selection    = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}
