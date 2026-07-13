
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
