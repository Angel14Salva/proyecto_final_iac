

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_public_a_id" {
  type = string
}

variable "subnet_public_b_id" {
  type = string
}

variable "subnet_private_a_id" {
  type = string
}

variable "subnet_private_b_id" {
  type = string
}

variable "sg_alb_id" {
  type = string
}

variable "sg_ecs_tasks_id" {
  type = string
}

variable "acm_certificate_arn" {
  type = string
}

variable "kms_secrets_key_arn" {
  type = string
}

variable "ecs_execution_role_arn" {
  type = string
}

variable "ecs_task_role_arn" {
  type = string
}

variable "s3_replication_role_arn" {
  type = string
}

variable "secret_db_credentials_arn" {
  type = string
}

variable "secret_cloudinary_arn" {
  type = string
}

variable "secret_jwt_arn" {
  type = string
}

variable "secret_smtp_arn" {
  type = string
}

variable "hibernate_ddl_auto" {
  description = "Modo de validacion de esquema de Hibernate. 'validate' en uso normal (nunca modifica el esquema). Cambiar a 'update' solo para la creacion inicial de tablas en una base nueva, y devolver a 'validate' de inmediato despues."
  type        = string
  default     = "validate"
}

variable "smtp_host" {
  description = "Servidor SMTP para el envio de notificaciones por email"
  type        = string
  default     = "smtp.gmail.com"
}

variable "smtp_port" {
  type    = string
  default = "587"
}

variable "mail_from" {
  description = "Direccion 'from' con la que el backend envia las notificaciones"
  type        = string
  default     = "notificaciones@segat.com"
}

variable "sqs_reportes_queue_url" {
  type = string
}

variable "sqs_notificaciones_queue_url" {
  type = string
}

variable "sns_negocio_topic_arn" {
  type = string
}

variable "dynamodb_gps_table_name" {
  type = string
}

variable "dynamodb_notifications_table_name" {
  type = string
}

variable "ecs_task_cpu" {
  type    = number
  default = 512
}

variable "ecs_task_memory" {
  type    = number
  default = 1024
}

variable "ecs_desired_count" {
  type    = number
  default = 2
}

variable "ecs_min_count" {
  type    = number
  default = 2
}

variable "ecs_max_count" {
  type    = number
  default = 6
}

variable "enable_s3_replication" {
  type    = bool
  default = false
}

variable "replication_bucket_alb" {
  type    = string
  default = "segat-alb-logs-replica"
}

