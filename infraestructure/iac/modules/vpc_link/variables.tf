
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

variable "alb_internal_https_listener_id" {
  description = "ID del listener HTTPS del ALB interno (modules.compute) -- fuerza el orden de creacion para que la asociacion ALB-target no falle."
  type        = string
}
