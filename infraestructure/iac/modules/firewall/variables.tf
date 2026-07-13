
variable "project_name" {
  type = string
}

variable "environment" {
  description = "Entorno de despliegue (dev, qa, prod) -- se usa para aislar nombres de recursos entre entornos"
  type        = string
}

variable "alb_external_arn" {
  type = string
}

variable "kms_secrets_key_arn" {
  type = string
}
