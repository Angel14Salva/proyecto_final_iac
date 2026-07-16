
# =============================================================================
# modules/stack/variables.tf
# Contrato de entrada del stack completo -- cada entorno
# (environments/{dev,qa,prod}) declara estas mismas variables con sus propios
# defaults y se las pasa tal cual a este modulo.
# =============================================================================

variable "aws_region" {
  type = string
}

variable "environment" {
  type = string
}

variable "project_name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "subnet_private_a_cidr" {
  type = string
}

variable "subnet_private_b_cidr" {
  type = string
}

variable "subnet_private_c_cidr" {
  type = string
}

variable "subnet_private_c2_cidr" {
  type = string
}

variable "subnet_public_cidr" {
  type = string
}

variable "subnet_public_b_cidr" {
  type = string
}

variable "hibernate_ddl_auto" {
  description = "Modo de validacion de esquema de Hibernate. 'validate' en uso normal. Cambiar a 'update' temporalmente solo para crear el esquema inicial en una base nueva."
  type        = bool
  default     = true
}

# --- Monitoreo ---

variable "grafana_admin_password" {
  description = "Password del usuario admin de Grafana"
  type        = string
  sensitive   = true
}

variable "prometheus_desired_count" {
  type    = number
  default = 1
}

variable "loki_desired_count" {
  type    = number
  default = 1
}

variable "grafana_desired_count" {
  type    = number
  default = 1
}

variable "ecs_task_cpu" {
  type = number
}

variable "ecs_task_memory" {
  type = number
}

variable "ecs_desired_count" {
  type = number
}

variable "ecs_min_count" {
  type = number
}

variable "ecs_max_count" {
  type = number
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "sqs_visibility_timeout" {
  type = number
}

variable "sqs_message_retention" {
  type = number
}

variable "sqs_dlq_max_receive" {
  type = number
}

variable "alert_email" {
  type = string
}

variable "replication_bucket_reportes" {
  type = string
}

variable "replication_bucket_alb" {
  type = string
}

variable "replication_bucket_cloudtrail" {
  type = string
}

variable "replication_bucket_frontend" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "github_repo" {
  type = string
}

variable "enable_secrets_rotation" {
  type = bool
}

variable "enable_s3_replication" {
  type = bool
}

variable "manage_apigw_account_settings" {
  description = "aws_api_gateway_account es un recurso a nivel de cuenta/region -- solo UN entorno de los desplegados en la misma cuenta/region debe tenerlo en true."
  type        = bool
}

variable "manage_config_recorder" {
  description = "aws_config_configuration_recorder es un recurso a nivel de cuenta/region (AWS solo permite UNO por cuenta/region) -- solo UN entorno de los desplegados en la misma cuenta/region debe tenerlo en true."
  type        = bool
}

variable "manage_oidc_provider" {
  description = "aws_iam_openid_connect_provider es unico por URL dentro de una cuenta AWS -- solo UN entorno de los desplegados en la misma cuenta debe tenerlo en true."
  type        = bool
}
