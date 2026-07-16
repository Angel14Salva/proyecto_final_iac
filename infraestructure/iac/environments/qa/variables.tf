
variable "aws_region" {
  description = "Region AWS donde se desplegara toda la infraestructura"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
  default     = "qa"
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default     = "segat"
}

variable "vpc_cidr" {
  type    = string
  default = "10.1.0.0/16"
}

variable "subnet_private_a_cidr" {
  type    = string
  default = "10.1.1.0/24"
}

variable "subnet_private_b_cidr" {
  type    = string
  default = "10.1.2.0/24"
}

variable "subnet_private_c_cidr" {
  type    = string
  default = "10.1.3.0/24"
}

variable "subnet_private_c2_cidr" {
  type    = string
  default = "10.1.4.0/24"
}

variable "subnet_public_cidr" {
  type    = string
  default = "10.1.10.0/24"
}

variable "subnet_public_b_cidr" {
  type    = string
  default = "10.1.11.0/24"
}

variable "ecs_task_cpu" {
  type    = number
  default = 512
}

variable "ecs_task_memory" {
  type    = number
  default = 1024
}

variable "ecs_desired_count" {
  type    = number
  default = 2
}

variable "ecs_min_count" {
  type    = number
  default = 2
}

variable "ecs_max_count" {
  type    = number
  default = 4
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
  description = "Password de RDS - pasar via TF_VAR_db_password"
  type        = string
  sensitive   = true
}

variable "sqs_visibility_timeout" {
  type    = number
  default = 30
}

variable "sqs_message_retention" {
  type    = number
  default = 345600
}

variable "sqs_dlq_max_receive" {
  type    = number
  default = 3
}

variable "alert_email" {
  type    = string
  default = "equipo-tecnico@segat.gob.pe"
}

variable "replication_bucket_reportes" {
  description = "Bucket destino para replicacion de reportes"
  type        = string
  default     = "segat-reportes-fotos-replica"
}

variable "replication_bucket_alb" {
  description = "Bucket destino para replicacion de ALB logs"
  type        = string
  default     = "segat-alb-logs-replica"
}

variable "replication_bucket_cloudtrail" {
  description = "Bucket destino para replicacion de CloudTrail logs"
  type        = string
  default     = "segat-cloudtrail-logs-replica"
}

variable "replication_bucket_frontend" {
  description = "Bucket destino para replicacion de assets del frontend"
  type        = string
  default     = "segat-frontend-replica"
}

variable "domain_name" {
  description = "Dominio principal del proyecto SEGAT"
  type        = string
  default     = "qa.segat.com"
}

variable "github_repo" {
  description = "Repositorio de GitHub (owner/repo) autorizado a asumir los roles OIDC"
  type        = string
  default     = "Angel14Salva/proyecto_final_iac"
}

variable "enable_secrets_rotation" {
  description = "Habilita la rotacion automatica de Secrets Manager. Requiere una Lambda de rotacion real desplegada previamente."
  type        = bool
  default     = false
}

variable "enable_s3_replication" {
  description = "Habilita la replicacion cross-region de los buckets S3 (reportes, alb_logs, cloudtrail_logs, frontend). Requiere que los buckets destino (replication_bucket_*) existan previamente."
  type        = bool
  default     = false
}

variable "manage_apigw_account_settings" {
  description = "aws_api_gateway_account es un recurso a nivel de cuenta/region -- solo UN entorno de los desplegados en la misma cuenta/region debe tenerlo en true (hoy: dev). qa lo deja en false para no chocar."
  type        = bool
  default     = false
}

variable "manage_config_recorder" {
  description = "aws_config_configuration_recorder es un recurso a nivel de cuenta/region (AWS solo permite UNO por cuenta/region) -- solo UN entorno debe tenerlo en true (hoy: dev). qa lo deja en false para no chocar."
  type        = bool
  default     = false
}

variable "manage_oidc_provider" {
  description = "aws_iam_openid_connect_provider es unico por URL dentro de una cuenta AWS -- solo UN entorno debe tenerlo en true (hoy: dev). qa lo deja en false para no chocar."
  type        = bool
  default     = false
}
