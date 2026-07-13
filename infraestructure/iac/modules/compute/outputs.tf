
output "ecr_repository_url" {
  value = aws_ecr_repository.segat_backend.repository_url
}

output "ecr_repository_arn" {
  value = aws_ecr_repository.segat_backend.arn
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "ecs_cluster_id" {
  value = aws_ecs_cluster.main.id
}

output "ecs_service_name" {
  value = aws_ecs_service.segat_backend.name
}

output "alb_external_arn" {
  value = aws_lb.external.arn
}

output "alb_external_dns_name" {
  value = aws_lb.external.dns_name
}

output "alb_external_zone_id" {
  value = aws_lb.external.zone_id
}

output "alb_internal_arn" {
  value = aws_lb.internal.arn
}

output "alb_internal_dns_name" {
  value = aws_lb.internal.dns_name
}

output "alb_logs_bucket_id" {
  value = aws_s3_bucket.alb_logs.id
}

output "alb_logs_bucket_arn" {
  value = aws_s3_bucket.alb_logs.arn
}

output "alb_logs_bucket_domain_name" {
  value = aws_s3_bucket.alb_logs.bucket_domain_name
}

# Se exponen para que otros modulos (ej. vpc_link) puedan forzar el orden de
# creacion via depends_on cuando lo necesiten, igual que hacia este archivo
# antes de dividirse en modulos.
output "alb_logs_bucket_policy_id" {
  value = aws_s3_bucket_policy.alb_logs.id
}

output "alb_logs_bucket_ownership_controls_id" {
  value = aws_s3_bucket_ownership_controls.alb_logs.id
}

output "cloudwatch_log_group_ecs_arn" {
  value = aws_cloudwatch_log_group.ecs.arn
}

output "cloudwatch_log_group_ecs_name" {
  value = aws_cloudwatch_log_group.ecs.name
}
