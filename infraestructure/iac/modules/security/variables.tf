

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "aws_region" {
  description = "Region AWS (para construir ARNs de Lambda de rotacion y el principal de CloudWatch Logs)"
  type        = string
}

variable "enable_secrets_rotation" {
  description = "Habilita la rotacion automatica de Secrets Manager. Requiere una Lambda de rotacion real desplegada previamente."
  type        = bool
  default     = false
}

variable "environment" {
  description = "Entorno de despliegue (no se usa en nombres de recursos en este modulo -- se mantiene el naming legado para no romper recursos ya aplicados; se declara solo para que modules/stack pueda pasarlo uniformemente a los 14 modulos)"
  type        = string
  default     = "production"
}

