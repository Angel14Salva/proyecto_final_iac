

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "kms_secrets_key_arn" {
  type = string
}

variable "secret_db_credentials_id" {
  type = string
}

variable "db_instance_address" {
  type      = string
  sensitive = true
}

variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_name" {
  type = string
}

variable "ecs_cluster_name" {
  type = string
}

variable "ecs_service_name" {
  type = string
}

variable "sns_alertas_arn" {
  type = string
}

variable "sns_alertas_name" {
  description = "Nombre corto (no ARN) del topico SNS de alertas -- CloudTrail lo normaliza a nombre corto al leerlo, pasar el ARN causa un diff perpetuo."
  type        = string
}

variable "sns_alertas_policy_id" {
  description = "ID de la policy del topico SNS de alertas (modules.messaging) -- fuerza el orden de creacion para que CloudTrail no falle con InsufficientSnsTopicPolicyException"
  type        = string
}

variable "sqs_reportes_dlq_name" {
  type = string
}

variable "s3_replication_role_arn" {
  type = string
}

variable "enable_s3_replication" {
  type    = bool
  default = false
}

variable "replication_bucket_cloudtrail" {
  type    = string
  default = "segat-cloudtrail-logs-replica"
}

variable "manage_config_recorder" {
  description = "aws_config_configuration_recorder es un recurso a nivel de cuenta/region (AWS solo permite UNO por cuenta/region) -- si hay varios entornos (dev/qa/prod) en la misma cuenta/region, solo UNO debe crearlo (los demas en false) para no chocar entre si."
  type        = bool
  default     = true
}

