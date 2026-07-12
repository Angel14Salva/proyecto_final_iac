variable "project_name" {
  description = "Nombre base para etiquetar y nombrar los recursos"
  type        = string
  default     = "segat-frontend"
}

variable "aws_region" {
  description = "Región donde se despliega el bucket S3 (CloudFront/WAF son globales/us-east-1)"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Entorno (dev, staging, prod)"
  type        = string
  default     = "prod"
}
