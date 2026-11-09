variable "aws_region" {
  description = "Región de AWS"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Prefijo para nombrar recursos (minúsculas y guiones, máx. 20 caracteres)"
  type        = string
  default     = "tareas-devops"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.project))
    error_message = "project debe tener 3-20 caracteres: minúsculas, números o guiones."
  }
}

variable "environment" {
  description = "Nombre del entorno"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "Bloque CIDR de la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "image_tag" {
  description = "Tag inicial de las imágenes. Después, el Pipeline 3 es quien actualiza las versiones."
  type        = string
  default     = "latest"
}

variable "frontend_desired_count" {
  description = "Número de tareas del frontend"
  type        = number
  default     = 2
}

variable "backend_desired_count" {
  description = "Número de tareas del backend (1 porque guarda datos en memoria)"
  type        = number
  default     = 1
}

variable "task_cpu" {
  description = "CPU por tarea Fargate (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Memoria por tarea Fargate en MiB"
  type        = number
  default     = 512
}

variable "log_retention_days" {
  description = "Días de retención de logs en CloudWatch"
  type        = number
  default     = 7
}
