
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

variable "manage_account_settings" {
  description = "aws_api_gateway_account es un recurso a nivel de cuenta/region, no por API -- si hay varios entornos (dev/qa/prod) en la misma cuenta/region, solo UNO debe crearlo (los demas en false) para no pisarse entre si."
  type        = bool
  default     = true
}
