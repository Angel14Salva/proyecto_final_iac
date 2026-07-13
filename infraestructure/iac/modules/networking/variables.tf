
variable "project_name" {
  type = string
}

variable "environment" {
  description = "Entorno de despliegue (dev, qa, prod) -- se usa para aislar nombres de recursos entre entornos"
  type        = string
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
