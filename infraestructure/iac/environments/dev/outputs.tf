
output "vpc_id" {
  description = "ID de la VPC principal de SEGAT"
  value       = module.networking.vpc_id
}

output "alb_external_dns" {
  description = "DNS del ALB externo — apuntar el registro CNAME de tu dominio aqui"
  value       = module.compute.alb_external_dns_name
}

output "alb_internal_dns" {
  description = "DNS del ALB interno"
  value       = module.compute.alb_internal_dns_name
}

output "ecs_cluster_name" {
  description = "Nombre del ECS Cluster"
  value       = module.compute.ecs_cluster_name
}

output "ecr_repository_url" {
  description = "URL del repositorio ECR para el pipeline CI/CD"
  value       = module.compute.ecr_repository_url
}

output "rds_endpoint" {
  description = "Endpoint de RDS PostgreSQL"
  value       = module.database.db_instance_address
  sensitive   = true
}

output "redis_primary_endpoint" {
  description = "Endpoint primario de ElastiCache Redis"
  value       = module.database.redis_primary_endpoint
  sensitive   = true
}

output "sqs_reportes_url" {
  description = "URL de la cola SQS de Reportes"
  value       = module.messaging.sqs_reportes_url
}

output "sqs_notificaciones_url" {
  description = "URL de la cola SQS de Notificaciones"
  value       = module.messaging.sqs_notificaciones_url
}

output "s3_reportes_bucket" {
  description = "Nombre del bucket S3 para fotografias de reportes (backup)"
  value       = module.database.s3_reportes_bucket
}

output "dynamodb_gps_table" {
  description = "Nombre de la tabla DynamoDB para GPS"
  value       = module.database.dynamodb_gps_table_name
}

output "cognito_user_pool_id" {
  description = "ID del Cognito User Pool de SEGAT"
  value       = module.auth.user_pool_id
}

output "cognito_user_pool_client_id" {
  description = "ID del cliente Cognito para el backend"
  value       = module.auth.user_pool_client_id
}

output "cognito_domain" {
  description = "Dominio de autenticacion Cognito"
  value       = module.auth.user_pool_domain
}

output "vpc_endpoint_dynamodb_id" {
  description = "ID del VPC Endpoint para DynamoDB"
  value       = module.database.vpc_endpoint_dynamodb_id
}

output "cloudfront_domain_name" {
  description = "Dominio de CloudFront — sirve el frontend (/) y proxea el backend (/api/*)"
  value       = module.cdn.cloudfront_domain_name
}

output "cloudfront_distribution_id" {
  description = "ID de la distribucion CloudFront — usado por el pipeline de deploy del frontend para invalidar cache"
  value       = module.cdn.cloudfront_distribution_id
}

output "s3_frontend_bucket" {
  description = "Nombre del bucket S3 donde se publican los assets estaticos del frontend"
  value       = module.cdn.s3_frontend_bucket
}

output "api_gateway_invoke_url" {
  description = "URL de invocacion del API Gateway (stage prod)"
  value       = module.api_gateway.invoke_url
}

output "internal_nlb_dns_name" {
  description = "DNS del NLB del VPC Link — puente entre API Gateway y el ALB interno"
  value       = module.vpc_link.internal_nlb_dns_name
}

output "config_recorder_status" {
  description = "Nombre del AWS Config Recorder (auditoria de configuracion / drift)"
  value       = module.observability.config_recorder_name
}

output "github_actions_role_arn" {
  description = "ARN del rol que GitHub Actions asume via OIDC — copiar al secret AWS_GHA_ROLE_ARN del repo"
  value       = module.oidc.github_actions_role_arn
}

output "github_actions_frontend_role_arn" {
  description = "ARN del rol que GitHub Actions asume via OIDC para desplegar el frontend — copiar al secret/var AWS_GHA_FRONTEND_ROLE_ARN del repo"
  value       = module.oidc.github_actions_frontend_role_arn
}

output "route53_name_servers" {
  description = "Name servers de la Hosted Zone — configurar en el registrador del dominio"
  value       = module.dns.name_servers
}
