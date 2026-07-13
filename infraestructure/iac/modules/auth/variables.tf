
variable "project_name" {
  type = string
}

variable "environment" {
  description = "Entorno de despliegue (dev, qa, prod) -- se usa para aislar nombres de recursos entre entornos"
  type        = string
}
