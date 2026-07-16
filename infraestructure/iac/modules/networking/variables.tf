

variable "project_name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "subnet_public_cidr" {
  type = string
}

variable "subnet_public_b_cidr" {
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

variable "kms_secrets_key_arn" {
  description = "ARN de la KMS key compartida (modules/security) para cifrar el log group de VPC Flow Logs"
  type        = string
}

variable "ecs_execution_role_arn" {
  description = "ARN del rol de ejecucion ECS (modules/security), reutilizado como rol de VPC Flow Logs"
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue (no se usa en nombres de recursos en este modulo -- se mantiene el naming legado para no romper recursos ya aplicados; se declara solo para que modules/stack pueda pasarlo uniformemente a los 14 modulos)"
  type        = string
  default     = "production"
}

