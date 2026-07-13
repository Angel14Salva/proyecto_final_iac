
variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "subnet_private_a_id" {
  type = string
}

variable "subnet_private_b_id" {
  type = string
}

variable "sg_ecs_tasks_id" {
  type = string
}

variable "alb_internal_arn" {
  type = string
}

variable "alb_logs_bucket_id" {
  type = string
}
