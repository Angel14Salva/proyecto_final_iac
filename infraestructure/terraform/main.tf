# =============================================================================
# SEGAT - Sistema de Gestión de Reportes Medio Ambientales
# Infraestructura como Código — Terraform
# Universidad Privada Antenor Orrego
# Curso: Infraestructura como Código (ISIA-107)
# =============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "SEGAT"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Course      = "Infraestructura-como-Codigo-UPAO"
    }
  }
}
