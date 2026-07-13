
# =============================================================================
# SEGAT - Sistema de Gestión de Reportes Medio Ambientales
# Infraestructura como Código — Terraform (modular)
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
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # backend "s3" { ... } -- configurar backend remoto aqui (o via -backend-config)
  # antes de hacer terraform init. Mientras tanto, el state queda local.
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

# Provider adicional en us-east-1 requerido para recursos globales de CloudFront
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

