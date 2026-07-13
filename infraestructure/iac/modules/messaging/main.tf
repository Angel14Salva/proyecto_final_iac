
# =============================================================================
# modules/messaging/main.tf
# SQS Colas + Dead Letter Queues + SNS Topics
# =============================================================================

data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

resource "aws_sqs_queue" "reportes_dlq" {
  name                      = "${local.name_prefix}-reportes-dlq"
  message_retention_seconds = 1209600
  kms_master_key_id         = aws_kms_key.sqs.arn
  tags                      = { Name = "${local.name_prefix}-sqs-reportes-dlq" }
}

resource "aws_sqs_queue" "reportes" {
  name                       = "${local.name_prefix}-cola-reportes"
  visibility_timeout_seconds = var.sqs_visibility_timeout
  message_retention_seconds  = var.sqs_message_retention
  receive_wait_time_seconds  = 20
  kms_master_key_id          = aws_kms_key.sqs.arn
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.reportes_dlq.arn
    maxReceiveCount     = var.sqs_dlq_max_receive
  })
  tags = { Name = "${local.name_prefix}-sqs-reportes" }
}

resource "aws_sqs_queue" "notificaciones_dlq" {
  name                      = "${local.name_prefix}-notificaciones-dlq"
  message_retention_seconds = 1209600
  kms_master_key_id         = aws_kms_key.sqs.arn
  tags                      = { Name = "${local.name_prefix}-sqs-notificaciones-dlq" }
}

resource "aws_sqs_queue" "notificaciones" {
  name                       = "${local.name_prefix}-cola-notificaciones"
  visibility_timeout_seconds = var.sqs_visibility_timeout
  message_retention_seconds  = var.sqs_message_retention
  receive_wait_time_seconds  = 20
  kms_master_key_id          = aws_kms_key.sqs.arn
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.notificaciones_dlq.arn
    maxReceiveCount     = var.sqs_dlq_max_receive
  })
  tags = { Name = "${local.name_prefix}-sqs-notificaciones" }
}

resource "aws_sns_topic" "negocio" {
  name              = "${local.name_prefix}-sns-negocio"
  kms_master_key_id = "alias/aws/sns"
  tags              = { Name = "${local.name_prefix}-sns-negocio" }
}

resource "aws_sns_topic_subscription" "negocio_to_notificaciones" {
  topic_arn = aws_sns_topic.negocio.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.notificaciones.arn
}

resource "aws_sqs_queue_policy" "notificaciones_policy" {
  queue_url = aws_sqs_queue.notificaciones.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.notificaciones.arn
      Condition = { ArnEquals = { "aws:SourceArn" = aws_sns_topic.negocio.arn } }
    }]
  })
}

# CloudTrail necesita un CMK (key administrada por nosotros) para publicar en
# un topico SNS cifrado -- la policy del alias administrado por AWS
# ("alias/aws/sns") no se puede editar, asi que CloudTrail nunca podria
# obtener el permiso que pide ("Edit the key policy to allow access to CloudTrail")
resource "aws_kms_key" "sns_alertas" {
  description             = "KMS CMK para el SNS topic de alertas (CloudTrail, CloudWatch Alarms)"
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
        Sid       = "AllowCloudTrail"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = ["kms:GenerateDataKey*", "kms:Decrypt"]
        Resource  = "*"
      },
      {
        Sid       = "AllowCloudWatchAlarms"
        Effect    = "Allow"
        Principal = { Service = "cloudwatch.amazonaws.com" }
        Action    = ["kms:GenerateDataKey*", "kms:Decrypt"]
        Resource  = "*"
      }
    ]
  })
  tags = { Name = "${local.name_prefix}-kms-sns-alertas" }
}

resource "aws_sns_topic" "alertas" {
  name              = "${local.name_prefix}-sns-alertas"
  kms_master_key_id = aws_kms_key.sns_alertas.arn
  tags              = { Name = "${local.name_prefix}-sns-alertas" }
}

resource "aws_sns_topic_subscription" "alertas_email" {
  topic_arn = aws_sns_topic.alertas.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Sin esto, aws_cloudtrail.main (modules/observability) falla con
# InsufficientSnsTopicPolicyException: CloudTrail necesita permiso explicito
# para publicar en el topico antes de poder usarlo como sns_topic_name
resource "aws_sns_topic_policy" "alertas" {
  arn = aws_sns_topic.alertas.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AWSCloudTrailSNSPolicy"
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "SNS:Publish"
      Resource  = aws_sns_topic.alertas.arn
    }]
  })
}

resource "aws_kms_key" "sqs" {
  description             = "KMS CMK para cifrado de colas SQS del proyecto SEGAT"
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
        Sid       = "Allow SQS to use this key"
        Effect    = "Allow"
        Principal = { Service = "sqs.amazonaws.com" }
        Action    = ["kms:GenerateDataKey", "kms:Decrypt"]
        Resource  = "*"
      }
    ]
  })
  tags = { Name = "${local.name_prefix}-kms-sqs" }
}

resource "aws_kms_alias" "sqs" {
  name          = "alias/${local.name_prefix}/sqs"
  target_key_id = aws_kms_key.sqs.key_id
}
