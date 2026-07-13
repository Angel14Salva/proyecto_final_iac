
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
