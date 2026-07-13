

# =============================================================================
# modules/messaging/main.tf
# SQS Colas + Dead Letter Queues + SNS Topics
# =============================================================================

data "aws_caller_identity" "current" {}

resource "aws_sqs_queue" "reportes_dlq" {
  name                      = "${var.project_name}-reportes-dlq"
  message_retention_seconds = 1209600
  kms_master_key_id         = aws_kms_key.sqs.arn
  tags                      = { Name = "${var.project_name}-sqs-reportes-dlq" }
}

resource "aws_sqs_queue" "reportes" {
  name                       = "${var.project_name}-cola-reportes"
  visibility_timeout_seconds = var.sqs_visibility_timeout
  message_retention_seconds  = var.sqs_message_retention
  receive_wait_time_seconds  = 20
  kms_master_key_id          = aws_kms_key.sqs.arn
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.reportes_dlq.arn
    maxReceiveCount     = var.sqs_dlq_max_receive
  })
  tags = { Name = "${var.project_name}-sqs-reportes" }
}

resource "aws_sqs_queue" "notificaciones_dlq" {
  name                      = "${var.project_name}-notificaciones-dlq"
  message_retention_seconds = 1209600
  kms_master_key_id         = aws_kms_key.sqs.arn
  tags                      = { Name = "${var.project_name}-sqs-notificaciones-dlq" }
}

resource "aws_sqs_queue" "notificaciones" {
  name                       = "${var.project_name}-cola-notificaciones"
  visibility_timeout_seconds = var.sqs_visibility_timeout
  message_retention_seconds  = var.sqs_message_retention
  receive_wait_time_seconds  = 20
  kms_master_key_id          = aws_kms_key.sqs.arn
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.notificaciones_dlq.arn
    maxReceiveCount     = var.sqs_dlq_max_receive
  })
  tags = { Name = "${var.project_name}-sqs-notificaciones" }
}

resource "aws_sns_topic" "negocio" {
  name              = "${var.project_name}-sns-negocio"
  kms_master_key_id = "alias/aws/sns"
  tags              = { Name = "${var.project_name}-sns-negocio" }
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
  tags = { Name = "${var.project_name}-kms-sns-alertas" }
}

resource "aws_sns_topic" "alertas" {
  name              = "${var.project_name}-sns-alertas"
  kms_master_key_id = aws_kms_key.sns_alertas.arn
  tags              = { Name = "${var.project_name}-sns-alertas" }
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
  tags = { Name = "${var.project_name}-kms-sqs" }
}

resource "aws_kms_alias" "sqs" {
  name          = "alias/${var.project_name}/sqs"
  target_key_id = aws_kms_key.sqs.key_id
}

