
variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "cognito_user_pool_arn" {
  type = string
}

variable "internal_nlb_dns_name" {
  type = string
}

variable "vpc_link_id" {
  type = string
}

variable "cloudwatch_log_group_ecs_arn" {
  type = string
}

variable "waf_main_arn" {
  type = string
}
