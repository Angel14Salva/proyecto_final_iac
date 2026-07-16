

variable "project_name" {
  type = string
}

variable "sqs_visibility_timeout" {
  type    = number
  default = 30
}

variable "sqs_message_retention" {
  type    = number
  default = 345600
}

variable "sqs_dlq_max_receive" {
  type    = number
  default = 3
}

variable "alert_email" {
  type = string
}

variable "environment" {
  description = "Entorno de despliegue (no se usa en nombres de recursos en este modulo -- se mantiene el naming legado para no romper recursos ya aplicados; se declara solo para que modules/stack pueda pasarlo uniformemente a los 14 modulos)"
  type        = string
  default     = "production"
}

