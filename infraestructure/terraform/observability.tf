# =============================================================================
# observability.tf — FASE 6: Observabilidad y Seguridad
# CloudWatch + Secrets Manager + CloudTrail
# =============================================================================

resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.project_name}/rds/credentials"
  description             = "Credenciales de RDS PostgreSQL para el monolito SEGAT"
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = 7
  tags                    = { Name = "${var.project_name}-secret-rds" }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = aws_db_instance.postgresql.address
    port     = 5432
    dbname   = var.db_name
  })
}

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
  tags          = { Name = "${var.project_name}-alarm-ecs-cpu" }
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
  tags                = { Name = "${var.project_name}-alarm-dlq-reportes" }
}

resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket        = "${var.project_name}-cloudtrail-logs-${var.environment}-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
  tags          = { Name = "${var.project_name}-s3-cloudtrail" }
}

resource "aws_s3_bucket_replication_configuration" "cloudtrail_logs" {
  count      = var.enable_s3_replication ? 1 : 0
  depends_on = [aws_s3_bucket_versioning.cloudtrail_logs]
  role       = aws_iam_role.s3_replication.arn
  bucket     = aws_s3_bucket.cloudtrail_logs.id
  rule {
    id     = "replicacion-cloudtrail"
    status = "Enabled"
    destination {
      bucket        = "arn:aws:s3:::${var.replication_bucket_cloudtrail}"
      storage_class = "STANDARD"
    }
  }
}

resource "aws_s3_bucket_notification" "cloudtrail_logs" {
  bucket      = aws_s3_bucket.cloudtrail_logs.id
  eventbridge = true
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
  kms_key_id                    = aws_kms_key.secrets.arn
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  sns_topic_name                = aws_sns_topic.alertas.arn
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_cloudwatch.arn
  tags                          = { Name = "${var.project_name}-cloudtrail" }
  depends_on                    = [aws_s3_bucket_policy.cloudtrail_logs, aws_sns_topic_policy.alertas]
}

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${var.project_name}"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.secrets.arn
  tags              = { Name = "${var.project_name}-cloudtrail-logs" }
}

resource "aws_iam_role" "cloudtrail_cloudwatch" {
  name = "${var.project_name}-cloudtrail-cloudwatch-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "cloudtrail_cloudwatch" {
  name = "${var.project_name}-cloudtrail-cloudwatch-policy"
  role = aws_iam_role.cloudtrail_cloudwatch.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
    }]
  })
}

# CKV2_AWS_57: Secrets Manager con rotacion automatica
resource "aws_secretsmanager_secret_rotation" "db_credentials" {
  count               = var.enable_secrets_rotation ? 1 : 0
  secret_id           = aws_secretsmanager_secret.db_credentials.id
  rotation_lambda_arn = "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:SecretsManagerRotation"
  rotation_rules {
    automatically_after_days = 30
  }
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
      # "alias/aws/s3" es la key administrada por AWS: su policy no se puede
      # editar, asi que CloudTrail nunca podria obtener permiso para escribir
      # en un bucket cifrado con ella. Usamos nuestra propia CMK (mas abajo en
      # este archivo), que si le otorga acceso explicito a CloudTrail.
      kms_master_key_id = aws_kms_key.secrets.arn
    }
  }
}

resource "aws_s3_bucket_logging" "cloudtrail_logs" {
  bucket        = aws_s3_bucket.cloudtrail_logs.id
  target_bucket = aws_s3_bucket.cloudtrail_logs.id
  target_prefix = "access-logs/"
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  rule {
    id     = "expire-old-logs"
    status = "Enabled"
    expiration { days = 365 }
    noncurrent_version_expiration { noncurrent_days = 90 }
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }
}





resource "aws_kms_key" "secrets" {
  description             = "KMS CMK para Secrets Manager y CloudTrail del proyecto SEGAT"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "Enable IAM User Permissions"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "Allow Secrets Manager"
        Effect    = "Allow"
        Principal = { Service = "secretsmanager.amazonaws.com" }
        Action    = ["kms:GenerateDataKey", "kms:Decrypt"]
        Resource  = "*"
      },
      {
        Sid       = "Allow CloudWatch Logs"
        Effect    = "Allow"
        Principal = { Service = "logs.${var.aws_region}.amazonaws.com" }
        Action    = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
        Resource  = "*"
      },
      # CloudTrail necesita esto tanto para cifrar el trail (kms_key_id en
      # aws_cloudtrail.main) como para poder escribir los logs en el bucket S3
      # (que tambien usa esta key para su cifrado por defecto, ver mas abajo)
      {
        Sid       = "Allow CloudTrail"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
        Resource  = "*"
      }
    ]
  })
  tags = { Name = "${var.project_name}-kms-secrets" }
}

resource "aws_secretsmanager_secret_rotation" "cloudinary" {
  count               = var.enable_secrets_rotation ? 1 : 0
  secret_id           = aws_secretsmanager_secret.cloudinary.id
  rotation_lambda_arn = "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:SecretsManagerRotation"
  rotation_rules {
    automatically_after_days = 30
  }
}

resource "aws_secretsmanager_secret_rotation" "jwt" {
  count               = var.enable_secrets_rotation ? 1 : 0
  secret_id           = aws_secretsmanager_secret.jwt.id
  rotation_lambda_arn = "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:SecretsManagerRotation"
  rotation_rules {
    automatically_after_days = 30
  }
}

resource "aws_secretsmanager_secret_rotation" "n8n" {
  count               = var.enable_secrets_rotation ? 1 : 0
  secret_id           = aws_secretsmanager_secret.n8n.id
  rotation_lambda_arn = "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:SecretsManagerRotation"
  rotation_rules {
    automatically_after_days = 30
  }
}

resource "aws_secretsmanager_secret" "cloudinary" {
  name        = "${var.project_name}/cloudinary"
  description = "Credenciales de Cloudinary para el proyecto SEGAT"
  kms_key_id  = aws_kms_key.secrets.arn
  tags        = { Name = "${var.project_name}-secret-cloudinary" }
}

resource "aws_secretsmanager_secret" "jwt" {
  name        = "${var.project_name}/jwt"
  description = "Secretos JWT para autenticacion del proyecto SEGAT"
  kms_key_id  = aws_kms_key.secrets.arn
  tags        = { Name = "${var.project_name}-secret-jwt" }
}

resource "aws_secretsmanager_secret" "n8n" {
  name        = "${var.project_name}/n8n"
  description = "Webhooks de n8n para el proyecto SEGAT"
  kms_key_id  = aws_kms_key.secrets.arn
  tags        = { Name = "${var.project_name}-secret-n8n" }
}
