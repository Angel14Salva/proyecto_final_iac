
variable "project_name" {
  type = string
}

variable "environment" {
  description = "Entorno de despliegue (dev, qa, prod) -- se usa para aislar nombres de recursos entre entornos"
  type        = string
}

variable "domain_name" {
  type = string
}

variable "alb_external_dns_name" {
  type = string
}

variable "alb_external_zone_id" {
  type = string
}
