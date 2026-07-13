

variable "project_name" {
  type = string
}

variable "github_repo" {
  description = "Repositorio de GitHub en formato owner/repo, usado para restringir que rol puede asumir el OIDC"
  type        = string
  default     = "Angel14Salva/proyecto_final_iac"
}

variable "ecr_repository_arn" {
  type = string
}

variable "s3_frontend_bucket_arn" {
  type = string
}

variable "cloudfront_distribution_arn" {
  type = string
}

variable "environment" {
  description = "Entorno de despliegue (no se usa en nombres de recursos en este modulo -- se mantiene el naming legado para no romper recursos ya aplicados)"
  type        = string
  default     = "production"
}

variable "manage_oidc_provider" {
  description = "aws_iam_openid_connect_provider es unico por URL dentro de una cuenta AWS (AWS rechaza un segundo provider con la misma URL) -- solo UN entorno de los desplegados en la misma cuenta debe tenerlo en true. Los demas reutilizan su ARN (predecible: no depende de que el recurso exista en su propio state)."
  type        = bool
  default     = true
}

