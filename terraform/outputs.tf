output "app_url" {
  description = "URL pública de la aplicación"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ecr_frontend_url" {
  value = aws_ecr_repository.app["frontend"].repository_url
}

output "ecr_backend_url" {
  value = aws_ecr_repository.app["backend"].repository_url
}

output "ecs_cluster" {
  value = aws_ecs_cluster.main.name
}

output "ecs_service_frontend" {
  value = aws_ecs_service.app["frontend"].name
}

output "ecs_service_backend" {
  value = aws_ecs_service.app["backend"].name
}

output "vpc_id" {
  value = aws_vpc.main.id
}
