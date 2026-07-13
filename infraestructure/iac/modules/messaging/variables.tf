
variable "project_name" {
  type = string
}

variable "environment" {
  description = "Entorno de despliegue (dev, qa, prod) -- se usa para aislar nombres de recursos entre entornos"
  type        = string
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
