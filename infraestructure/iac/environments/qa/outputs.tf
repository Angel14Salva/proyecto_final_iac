
output "vpc_id" {
  description = "ID de la VPC principal de SEGAT"
  value       = module.segat.vpc_id
}

output "alb_external_dns" {
  description = "DNS del ALB externo — apuntar el registro CNAME de tu dominio aqui"
  value       = module.segat.alb_external_dns
}

output "alb_internal_dns" {
  description = "DNS del ALB interno"
  value       = module.segat.alb_internal_dns
}

output "ecs_cluster_name" {
  description = "Nombre del ECS Cluster"
  value       = module.segat.ecs_cluster_name
}

output "ecr_repository_url" {
  description = "URL del repositorio ECR para el pipeline CI/CD"
  value       = module.segat.ecr_repository_url
}

output "rds_endpoint" {
  description = "Endpoint de RDS PostgreSQL"
  value       = module.segat.rds_endpoint
  sensitive   = true
}

output "redis_primary_endpoint" {
  description = "Endpoint primario de ElastiCache Redis"
  value       = module.segat.redis_primary_endpoint
  sensitive   = true
}

output "sqs_reportes_url" {
  description = "URL de la cola SQS de Reportes"
  value       = module.segat.sqs_reportes_url
}

output "sqs_notificaciones_url" {
  description = "URL de la cola SQS de Notificaciones"
  value       = module.segat.sqs_notificaciones_url
}

output "s3_reportes_bucket" {
  description = "Nombre del bucket S3 para fotografias de reportes (backup)"
  value       = module.segat.s3_reportes_bucket
}

output "dynamodb_gps_table" {
  description = "Nombre de la tabla DynamoDB para GPS"
  value       = module.segat.dynamodb_gps_table
}

output "cognito_user_pool_id" {
  description = "ID del Cognito User Pool de SEGAT"
  value       = module.segat.cognito_user_pool_id
}

output "cognito_user_pool_client_id" {
  description = "ID del cliente Cognito para el backend"
  value       = module.segat.cognito_user_pool_client_id
}

output "cognito_domain" {
  description = "Dominio de autenticacion Cognito"
  value       = module.segat.cognito_domain
}

output "vpc_endpoint_dynamodb_id" {
  description = "ID del VPC Endpoint para DynamoDB"
  value       = module.segat.vpc_endpoint_dynamodb_id
}

output "cloudfront_domain_name" {
  description = "Dominio de CloudFront — sirve el frontend (/) y proxea el backend (/api/*)"
  value       = module.segat.cloudfront_domain_name
}

output "cloudfront_distribution_id" {
  description = "ID de la distribucion CloudFront — usado por el pipeline de deploy del frontend para invalidar cache"
  value       = module.segat.cloudfront_distribution_id
}

output "s3_frontend_bucket" {
  description = "Nombre del bucket S3 donde se publican los assets estaticos del frontend"
  value       = module.segat.s3_frontend_bucket
}

output "api_gateway_invoke_url" {
  description = "URL de invocacion del API Gateway (stage prod)"
  value       = module.segat.api_gateway_invoke_url
}

output "internal_nlb_dns_name" {
  description = "DNS del NLB del VPC Link — puente entre API Gateway y el ALB interno"
  value       = module.segat.internal_nlb_dns_name
}

output "config_recorder_status" {
  description = "Nombre del AWS Config Recorder (auditoria de configuracion / drift)"
  value       = module.segat.config_recorder_status
}

output "github_actions_role_arn" {
  description = "ARN del rol que GitHub Actions asume via OIDC — copiar al secret AWS_GHA_ROLE_ARN del repo"
  value       = module.segat.github_actions_role_arn
}

output "github_actions_frontend_role_arn" {
  description = "ARN del rol que GitHub Actions asume via OIDC para desplegar el frontend — copiar al secret/var AWS_GHA_FRONTEND_ROLE_ARN del repo"
  value       = module.segat.github_actions_frontend_role_arn
}

output "route53_name_servers" {
  description = "Name servers de la Hosted Zone — configurar en el registrador del dominio"
  value       = module.segat.route53_name_servers
}
