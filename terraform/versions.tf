terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Estado remoto en S3 (configuración parcial: bucket/key/region se pasan con -backend-config).
  # use_lockfile=true usa bloqueo nativo de S3 (Terraform >= 1.10), sin necesidad de DynamoDB.
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Proyecto  = var.project
      Entorno   = var.environment
      ManagedBy = "terraform"
    }
  }
}
