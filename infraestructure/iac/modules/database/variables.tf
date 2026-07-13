
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

variable "subnet_private_c_id" {
  type = string
}

variable "subnet_private_c2_id" {
  type = string
}

variable "route_table_private_id" {
  type = string
}

variable "sg_rds_id" {
  type = string
}

variable "sg_redis_id" {
  type = string
}

variable "rds_monitoring_role_arn" {
  type = string
}

variable "s3_replication_role_arn" {
  type = string
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
  sensitive = true
}

variable "enable_s3_replication" {
  type    = bool
  default = false
}

variable "replication_bucket_reportes" {
  type    = string
  default = "segat-reportes-fotos-replica"
}
