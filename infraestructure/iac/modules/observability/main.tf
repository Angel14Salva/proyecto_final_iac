


# =============================================================================
# modules/observability/main.tf
# CloudWatch Alarms + CloudTrail + AWS Config
#
# Fusiona los antiguos observability.tf y aws-config.tf (AWS Config reutiliza
# el bucket de CloudTrail de este mismo modulo). La KMS key compartida y los
# "contenedores" de Secrets Manager (metadatos sin valor) viven en
# modules/security -- aqui solo se llena el VALOR de db_credentials, porque
# recien aqui se conoce el endpoint de RDS (modules/database).
# =============================================================================

data "aws_caller_identity" "current" {}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = var.secret_db_credentials_id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = var.db_instance_address
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
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }
  alarm_actions = [var.sns_alertas_arn]
  ok_actions    = [var.sns_alertas_arn]
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
  dimensions          = { QueueName = var.sqs_reportes_dlq_name }
  alarm_actions       = [var.sns_alertas_arn]
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
  role       = var.s3_replication_role_arn
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

# Mismo problema que con alb_logs (modules.compute): la policy de este bucket
# exige el ACL "bucket-owner-full-control", pero los buckets S3 nuevos nacen
# con ACLs deshabilitadas ("Bucket owner enforced") desde abril 2023. Sin
# esto, CloudTrail no podria escribir el primer log aunque la policy sea
# correcta.
resource "aws_s3_bucket_ownership_controls" "cloudtrail_logs" {
  # checkov:skip=CKV2_AWS_65: Igual que alb_logs (modules.compute) --
  # CloudTrail exige el ACL "bucket-owner-full-control" para escribir.
  # Deshabilitar ACLs rompe la entrega de logs.
  bucket = aws_s3_bucket.cloudtrail_logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
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
      },
      {
        Sid       = "AWSConfigAclCheck"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.cloudtrail_logs.arn
      },
      {
        Sid       = "AWSConfigWrite"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*"
        Condition = { StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" } }
      }
    ]
  })
}

resource "aws_cloudtrail" "main" {
  name                          = "${var.project_name}-cloudtrail"
  kms_key_id                    = var.kms_secrets_key_arn
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  sns_topic_name                = var.sns_alertas_name
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_cloudwatch.arn
  tags                          = { Name = "${var.project_name}-cloudtrail" }
  depends_on = [
    aws_s3_bucket_policy.cloudtrail_logs,
    aws_s3_bucket_ownership_controls.cloudtrail_logs,
    # Sin esperar a que la policy del topico SNS este lista, CloudTrail falla
    # con InsufficientSnsTopicPolicyException (ya nos paso una vez). La
    # policy vive en modules.messaging; se referencia via variable porque
    # depends_on SI acepta valores derivados de otro modulo.
    var.sns_alertas_policy_id,
  ]
}

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${var.project_name}"
  retention_in_days = 365
  kms_key_id        = var.kms_secrets_key_arn
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

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
      # "alias/aws/s3" es la key administrada por AWS: su policy no se puede
      # editar, asi que CloudTrail nunca podria obtener permiso para escribir
      # en un bucket cifrado con ella. Usamos la CMK compartida
      # (modules.security), que si le otorga acceso explicito a CloudTrail.
      kms_master_key_id = var.kms_secrets_key_arn
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
    filter {}
    expiration { days = 365 }
    noncurrent_version_expiration { noncurrent_days = 90 }
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }
}

# ---------------------------------------------------------------------------
# AWS Config — auditoria de configuracion y deteccion de drift. Reutiliza el
# bucket de CloudTrail de arriba como destino de los snapshots.
# ---------------------------------------------------------------------------
resource "aws_iam_role" "config" {
  # aws_config_configuration_recorder es un recurso a nivel de cuenta/region
  # (AWS solo permite UNO por cuenta/region) -- solo UN entorno debe
  # tenerlo en true.
  count = var.manage_config_recorder ? 1 : 0
  name  = "${var.project_name}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "${var.project_name}-role-config" }
}

resource "aws_iam_role_policy_attachment" "config" {
  count      = var.manage_config_recorder ? 1 : 0
  role       = aws_iam_role.config[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_iam_role_policy" "config_s3" {
  count = var.manage_config_recorder ? 1 : 0
  name  = "${var.project_name}-config-s3-policy"
  role  = aws_iam_role.config[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ConfigBucketAcl"
        Effect   = "Allow"
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_logs.arn
      },
      {
        Sid      = "ConfigBucketWrite"
        Effect   = "Allow"
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*"
      }
    ]
  })
}

resource "aws_config_configuration_recorder" "main" {
  count    = var.manage_config_recorder ? 1 : 0
  name     = "${var.project_name}-config-recorder"
  role_arn = aws_iam_role.config[0].arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "main" {
  count          = var.manage_config_recorder ? 1 : 0
  name           = "${var.project_name}-config-delivery"
  s3_bucket_name = aws_s3_bucket.cloudtrail_logs.id
  # NO fijar s3_key_prefix con "AWSLogs/..." -- AWS Config genera esa ruta
  # automaticamente. Si se especifica, la duplica y falla con
  # InvalidS3KeyPrefixException: "Ensure you do not have 'AWSLogs/' in your prefix."

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_configuration_recorder_status" "main" {
  count      = var.manage_config_recorder ? 1 : 0
  name       = aws_config_configuration_recorder.main[0].name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.main]
}


