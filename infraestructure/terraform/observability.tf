# =============================================================================
# observability.tf — FASE 6: Observabilidad y Seguridad
# CloudWatch + Secrets Manager + CloudTrail
# =============================================================================

resource "aws_kms_key" "secrets" {
  description             = "CMK para Secrets Manager de ${var.project_name}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = { Name = "${var.project_name}-kms-secrets" }
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.project_name}/secrets"
  target_key_id = aws_kms_key.secrets.key_id
}


# =============================================================================
# SECRETS MANAGER — Credenciales para el contenedor ECS
# =============================================================================

# Secret: credenciales RDS
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${var.project_name}/rds/credentials"
  description = "Credenciales de RDS PostgreSQL para el monolito SEGAT"
  kms_key_id  = aws_kms_key.secrets.arn
  tags        = { Name = "${var.project_name}-secret-rds" }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = aws_db_instance.postgresql.address
    port     = 5432
    dbname   = var.db_name
    url      = "jdbc:postgresql://${aws_db_instance.postgresql.address}:5432/${var.db_name}"
  })
}

# Secret: credenciales Cloudinary para subida de imagenes
resource "aws_secretsmanager_secret" "cloudinary" {
  name        = "${var.project_name}/cloudinary/credentials"
  description = "Credenciales Cloudinary para el servicio de subida de imagenes"
  kms_key_id  = aws_kms_key.secrets.arn
  tags        = { Name = "${var.project_name}-secret-cloudinary" }
}

resource "aws_secretsmanager_secret" "jwt" {
  name        = "${var.project_name}/jwt/config"
  description = "Configuracion JWT: secret, expiration y refresh_expiration en milisegundos"
  kms_key_id  = aws_kms_key.secrets.arn
  tags        = { Name = "${var.project_name}-secret-jwt" }
}

resource "aws_secretsmanager_secret" "n8n" {
  name        = "${var.project_name}/n8n/webhooks"
  description = "URLs de webhooks n8n para notificaciones de reportes y tareas"
  kms_key_id  = aws_kms_key.secrets.arn
  tags        = { Name = "${var.project_name}-secret-n8n" }
}


# =============================================================================
# CLOUDWATCH ALARMS
# =============================================================================

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${var.project_name}-ecs-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU de Fargate supera 80%"
  treat_missing_data  = "notBreaching"
  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.segat_backend.name
  }
  alarm_actions = [aws_sns_topic.alertas.arn]
  ok_actions    = [aws_sns_topic.alertas.arn]
  tags = { Name = "${var.project_name}-alarm-ecs-cpu" }
}

resource "aws_cloudwatch_metric_alarm" "reportes_dlq_depth" {
  alarm_name          = "${var.project_name}-reportes-dlq-messages"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Hay reportes en la DLQ que no pudieron procesarse"
  treat_missing_data  = "notBreaching"
  dimensions          = { QueueName = aws_sqs_queue.reportes_dlq.name }
  alarm_actions       = [aws_sns_topic.alertas.arn]
  tags = { Name = "${var.project_name}-alarm-dlq-reportes" }
}

# =============================================================================
# CLOUDTRAIL
# =============================================================================

resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket        = "${var.project_name}-cloudtrail-logs-${var.environment}"
  force_destroy = true
  tags = { Name = "${var.project_name}-s3-cloudtrail" }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_logs" {
  bucket                  = aws_s3_bucket.cloudtrail_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.cloudtrail_logs.arn
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/*"
        Condition = { StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" } }
      }
    ]
  })
}

resource "aws_cloudtrail" "main" {
  name                          = "${var.project_name}-cloudtrail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  sns_topic_name = aws_sns_topic.alertas.name
  tags       = { Name = "${var.project_name}-cloudtrail" }
  depends_on = [aws_s3_bucket_policy.cloudtrail_logs]
}
