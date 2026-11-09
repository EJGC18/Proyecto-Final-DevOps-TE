# ALB: acepta HTTP desde Internet
resource "aws_security_group" "alb" {
  name        = "${var.project}-alb-sg"
  description = "Trafico HTTP publico hacia el ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP desde Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Salida hacia las tareas"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-alb-sg" }
}

# Tareas ECS: solo aceptan tráfico desde el ALB (frontend :80 y backend :3000)
resource "aws_security_group" "ecs" {
  name        = "${var.project}-ecs-sg"
  description = "Solo trafico desde el ALB hacia las tareas ECS"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Frontend desde el ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "Backend desde el ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Salida a Internet (descarga de imagenes ECR y logs)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-ecs-sg" }
}
