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
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
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

output "secret_cloudinary_arn" {
  description = "ARN del secret de Cloudinary (para poblar manualmente antes del deploy)"
  value       = aws_secretsmanager_secret.cloudinary.arn
}

output "secret_jwt_arn" {
  description = "ARN del secret JWT (para poblar manualmente antes del deploy)"
  value       = aws_secretsmanager_secret.jwt.arn
}

output "secret_n8n_arn" {
  description = "ARN del secret n8n webhooks (para poblar manualmente antes del deploy)"
  value       = aws_secretsmanager_secret.n8n.arn
}
