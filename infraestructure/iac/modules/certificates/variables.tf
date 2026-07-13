

variable "project_name" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "environment" {
  description = "Entorno de despliegue (no se usa en nombres de recursos en este modulo -- se mantiene el naming legado para no romper recursos ya aplicados; se declara solo para que modules/stack pueda pasarlo uniformemente a los 14 modulos)"
  type        = string
  default     = "production"
}

