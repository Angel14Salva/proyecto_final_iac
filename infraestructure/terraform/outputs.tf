# =============================================================================
# outputs.tf — Valores exportados despues del despliegue
# =============================================================================

output "vpc_id" {
  description = "ID de la VPC principal de SEGAT"
  value       = aws_vpc.main.id
}

output "alb_external_dns" {
  description = "DNS del ALB externo — apuntar el registro CNAME de tu dominio aqui"
  value       = aws_lb.external.dns_name
}

output "ecs_cluster_name" {
  description = "Nombre del ECS Cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecr_repository_url" {
  description = "URL del repositorio ECR para el pipeline CI/CD"
  value       = aws_ecr_repository.segat_backend.repository_url
}

output "rds_endpoint" {
  description = "Endpoint de RDS PostgreSQL"
  value       = aws_db_instance.postgresql.address
  sensitive   = true
}

output "redis_primary_endpoint" {
  description = "Endpoint primario de ElastiCache Redis (ReplicationGroup)"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
  sensitive   = true
}

output "sqs_reportes_url" {
  description = "URL de la cola SQS de Reportes"
  value       = aws_sqs_queue.reportes.url
}

output "sqs_notificaciones_url" {
  description = "URL de la cola SQS de Notificaciones"
  value       = aws_sqs_queue.notificaciones.url
}

output "s3_reportes_bucket" {
  description = "Nombre del bucket S3 para fotografias de reportes (backup)"
  value       = aws_s3_bucket.reportes.bucket
}

output "dynamodb_gps_table" {
  description = "Nombre de la tabla DynamoDB para GPS"
  value       = aws_dynamodb_table.gps_locations.name
}




output "cognito_user_pool_id" {
  description = "ID del Cognito User Pool de SEGAT"
  value       = aws_cognito_user_pool.segat.id
}

output "cognito_user_pool_client_id" {
  description = "ID del cliente Cognito para el backend"
  value       = aws_cognito_user_pool_client.segat_backend.id
}

output "cognito_domain" {
  description = "Dominio de autenticacion Cognito"
  value       = aws_cognito_user_pool_domain.segat.domain
}

output "alb_internal_dns" {
  description = "DNS del ALB interno"
  value       = aws_lb.internal.dns_name
}

output "vpc_endpoint_dynamodb_id" {
  description = "ID del VPC Endpoint para DynamoDB"
  value       = aws_vpc_endpoint.dynamodb.id
}
