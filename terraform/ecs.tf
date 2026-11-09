resource "aws_ecs_cluster" "main" {
  name = "${var.project}-cluster"

  setting {
    name = "containerInsights"
    # habilitar genera costo adicional
    value = "disabled"
  }
}

resource "aws_cloudwatch_log_group" "app" {
  for_each          = local.componentes
  name              = "/ecs/${var.project}/${each.key}"
  retention_in_days = var.log_retention_days
}

locals {
  contenedores = {
    frontend = {
      puerto       = 80
      desired      = var.frontend_desired_count
      target_group = aws_lb_target_group.frontend.arn
      environment  = []
    }
    backend = {
      puerto       = 3000
      desired      = var.backend_desired_count
      target_group = aws_lb_target_group.backend.arn
      environment  = [
        { name = "PORT", value = "3000" },
      ]
    }
  }
}

# Definición de tarea INICIAL. A partir de aquí, el Pipeline 3 registra nuevas revisiones
# con la imagen de cada commit, por eso el servicio ignora cambios en task_definition.
resource "aws_ecs_task_definition" "app" {
  for_each = local.contenedores

  family                   = "${var.project}-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name             = each.key
    image            = "${aws_ecr_repository.app[each.key].repository_url}:${var.image_tag}"
    essential        = true
    portMappings     = [{ containerPort = each.value.puerto, protocol = "tcp" }]
    environment      = each.value.environment
    logConfiguration = {
      logDriver = "awslogs"
      options   = {
        awslogs-group         = aws_cloudwatch_log_group.app[each.key].name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = each.key
      }
    }
  }])
}

resource "aws_ecs_service" "app" {
  for_each = local.contenedores

  name                              = "${var.project}-${each.key}"
  cluster                           = aws_ecs_cluster.main.id
  task_definition                   = aws_ecs_task_definition.app[each.key].arn
  desired_count                     = each.value.desired
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = 60

  # Manejo de errores: si una nueva versión no pasa los health checks,
  # ECS detiene el despliegue y vuelve automáticamente a la versión anterior.
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  network_configuration {
    subnets         = aws_subnet.publica[*].id
    security_groups = [aws_security_group.ecs.id]
    # necesario para llegar a ECR sin NAT Gateway
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = each.value.target_group
    container_name   = each.key
    container_port   = each.value.puerto
  }

  lifecycle {
    # lo gestiona el Pipeline 3
    ignore_changes = [task_definition]
  }

  depends_on = [aws_lb_listener.http, aws_lb_listener_rule.api]
}
