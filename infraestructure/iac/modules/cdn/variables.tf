

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "alb_external_dns_name" {
  type = string
}

variable "alb_internal_dns_name" {
  type = string
}

variable "alb_logs_bucket_id" {
  type = string
}

variable "alb_logs_bucket_domain_name" {
  type = string
}

variable "acm_certificate_arn" {
  type = string
}

variable "waf_cloudfront_arn" {
  type = string
}

variable "s3_replication_role_arn" {
  type = string
}

variable "enable_s3_replication" {
  type    = bool
  default = false
}

variable "replication_bucket_frontend" {
  type    = string
  default = "segat-frontend-replica"
}

