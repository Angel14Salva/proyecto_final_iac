
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

variable "secret_n8n_arn" {
  type = string
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
