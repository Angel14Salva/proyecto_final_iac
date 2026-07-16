# =============================================================================
# modules/monitoring/variables.tf
# =============================================================================

variable "project_name" { type = string }
variable "environment" { type = string }
variable "aws_region" { type = string }

variable "vpc_id" { type = string }
variable "subnet_private_a_id" { type = string }
variable "subnet_private_b_id" { type = string }
variable "subnet_public_a_id" { type = string }
variable "subnet_public_b_id" { type = string }

variable "ecs_cluster_id" { type = string }
variable "ecs_execution_role_arn" { type = string }
variable "kms_secrets_key_arn" { type = string }

variable "grafana_admin_password" {
  type      = string
  sensitive = true
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
