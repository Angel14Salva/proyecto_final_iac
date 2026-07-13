
output "kms_secrets_key_arn" {
  value = aws_kms_key.secrets.arn
}

output "kms_secrets_key_id" {
  value = aws_kms_key.secrets.key_id
}

output "ecs_execution_role_arn" {
  value = aws_iam_role.ecs_execution_role.arn
}

output "ecs_execution_role_name" {
  value = aws_iam_role.ecs_execution_role.name
}

output "ecs_task_role_arn" {
  value = aws_iam_role.ecs_task_role.arn
}

output "ecs_task_role_name" {
  value = aws_iam_role.ecs_task_role.name
}

output "autoscaling_role_arn" {
  value = aws_iam_role.autoscaling_role.arn
}

output "rds_monitoring_role_arn" {
  value = aws_iam_role.rds_monitoring.arn
}

output "s3_replication_role_arn" {
  value = aws_iam_role.s3_replication.arn
}

output "secret_db_credentials_id" {
  value = aws_secretsmanager_secret.db_credentials.id
}

output "secret_db_credentials_arn" {
  value = aws_secretsmanager_secret.db_credentials.arn
}

output "secret_cloudinary_arn" {
  value = aws_secretsmanager_secret.cloudinary.arn
}

output "secret_jwt_arn" {
  value = aws_secretsmanager_secret.jwt.arn
}

output "secret_n8n_arn" {
  value = aws_secretsmanager_secret.n8n.arn
}
