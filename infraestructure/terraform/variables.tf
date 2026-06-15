variable "aws_region" {
  description = "Region AWS donde se desplegara toda la infraestructura"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default     = "segat"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "subnet_private_a_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "subnet_private_b_cidr" {
  type    = string
  default = "10.0.2.0/24"
}

variable "subnet_private_c_cidr" {
  type    = string
  default = "10.0.3.0/24"
}

variable "subnet_private_c2_cidr" {
  type    = string
  default = "10.0.4.0/24"
}

variable "subnet_public_cidr" {
  type    = string
  default = "10.0.10.0/24"
}

variable "subnet_public_b_cidr" {
  type    = string
  default = "10.0.11.0/24"
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

variable "db_name" {
  type    = string
  default = "segat_db"
}

variable "db_username" {
  type      = string
  default   = "segat_admin"
  sensitive = true
}

variable "db_password" {
  type      = string
  default   = "ChangeMe_Pr0duction!"
  sensitive = true
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
  type    = string
  default = "equipo-tecnico@segat.gob.pe"
}
