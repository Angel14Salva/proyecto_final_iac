# =============================================================================
# messaging.tf — FASE 5: Mensajeria asincrona
# SQS + Dead Letter Queues + SNS
# =============================================================================

resource "aws_kms_key" "messaging" {
  description             = "CMK para SQS y SNS de ${var.project_name}"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  # SQS necesita permisos explícitos en la key policy para poder usar la CMK
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
        Sid    = "Allow SQS to use the key"
        Effect = "Allow"
        Principal = {
          Service = "sqs.amazonaws.com"
        }
        Action   = ["kms:GenerateDataKey", "kms:Decrypt"]
        Resource = "*"
      },
      {
        Sid    = "Allow SNS to use the key"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action   = ["kms:GenerateDataKey", "kms:Decrypt"]
        Resource = "*"
      }
    ]
  })

  tags = { Name = "${var.project_name}-kms-messaging" }
}

resource "aws_kms_alias" "messaging" {
  name          = "alias/${var.project_name}/messaging"
  target_key_id = aws_kms_key.messaging.key_id
}

# =============================================================================
# SQS — Colas de reportes
# =============================================================================

resource "aws_sqs_queue" "reportes_dlq" {
  name                      = "${var.project_name}-reportes-dlq"
  message_retention_seconds = 1209600
  # CKV2_AWS_73: CMK propio en lugar de alias/aws/sqs
  kms_master_key_id         = aws_kms_key.messaging.id
  tags                      = { Name = "${var.project_name}-sqs-reportes-dlq" }
}

resource "aws_sqs_queue" "reportes" {
  name                       = "${var.project_name}-cola-reportes"
  visibility_timeout_seconds = var.sqs_visibility_timeout
  message_retention_seconds  = var.sqs_message_retention
  receive_wait_time_seconds  = 20
  # CKV2_AWS_73: CMK propio en lugar de alias/aws/sqs
  kms_master_key_id          = aws_kms_key.messaging.id
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.reportes_dlq.arn
    maxReceiveCount     = var.sqs_dlq_max_receive
  })
  tags = { Name = "${var.project_name}-sqs-reportes" }
}

# =============================================================================
# SQS — Colas de notificaciones
# =============================================================================

resource "aws_sqs_queue" "notificaciones_dlq" {
  name                      = "${var.project_name}-notificaciones-dlq"
  message_retention_seconds = 1209600
  kms_master_key_id         = aws_kms_key.messaging.id
  tags                      = { Name = "${var.project_name}-sqs-notificaciones-dlq" }
}

resource "aws_sqs_queue" "notificaciones" {
  name                       = "${var.project_name}-cola-notificaciones"
  visibility_timeout_seconds = var.sqs_visibility_timeout
  message_retention_seconds  = var.sqs_message_retention
  receive_wait_time_seconds  = 20
  kms_master_key_id          = aws_kms_key.messaging.id
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.notificaciones_dlq.arn
    maxReceiveCount     = var.sqs_dlq_max_receive
  })
  tags = { Name = "${var.project_name}-sqs-notificaciones" }
}

# =============================================================================
# SNS
# =============================================================================

resource "aws_sns_topic" "negocio" {
  name              = "${var.project_name}-sns-negocio"
  # CKV_AWS_26: CMK propio en lugar de alias/aws/sns
  kms_master_key_id = aws_kms_key.messaging.id
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

resource "aws_sns_topic" "alertas" {
  name              = "${var.project_name}-sns-alertas"
  kms_master_key_id = "alias/aws/sns"
  tags = { Name = "${var.project_name}-sns-alertas" }
}

resource "aws_sns_topic_subscription" "alertas_email" {
  topic_arn = aws_sns_topic.alertas.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
