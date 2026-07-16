

# =============================================================================
# modules/security/main.tf
# IAM (roles de minimo privilegio) + KMS CMK compartida + contenedores de
# Secrets Manager (sin valores -- los valores que dependen de otros modulos,
# como db_credentials, se llenan desde modules/observability).
# =============================================================================

data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ---------------------------------------------------------------------------
# IAM Roles
# ---------------------------------------------------------------------------
resource "aws_iam_role" "ecs_execution_role" {
  name        = "${local.name_prefix}-ecs-execution-role"
  description = "Permite a ECS Fargate descargar imagenes de ECR y enviar logs"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name = "${local.name_prefix}-ecs-execution-secrets"
  role = aws_iam_role.ecs_execution_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "SecretsManagerAccess"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "ssm:GetParameters"]
        Resource = "arn:aws:secretsmanager:*:*:secret:${local.name_prefix}/*"
      },
      {
        # La key policy de aws_kms_key.secrets delega el control de acceso a
        # IAM (statement "Enable IAM User Permissions"), asi que el rol
        # necesita su propio permiso explicito de kms:Decrypt -- sin esto,
        # ECS Fargate no puede resolver los "valueFrom" del task definition
        # y las tareas mueren con ResourceInitializationError / AccessDeniedException.
        Sid      = "KMSDecryptSecrets"
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = aws_kms_key.secrets.arn
      }
    ]
  })
}

resource "aws_iam_role" "ecs_task_role" {
  name        = "${local.name_prefix}-ecs-task-role"
  description = "Permisos del monolito SEGAT: SQS, S3, DynamoDB, Secrets"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ecs_task_permissions" {
  name = "${local.name_prefix}-ecs-task-permissions"
  role = aws_iam_role.ecs_task_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "SQSAccess"
        Effect   = "Allow"
        Action   = ["sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = "arn:aws:sqs:*:*:${local.name_prefix}-*"
      },
      {
        Sid      = "S3ReportesAccess"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::${local.name_prefix}-reportes-*/*"
      },
      {
        Sid      = "DynamoDBAccess"
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:UpdateItem", "dynamodb:Query", "dynamodb:Scan"]
        Resource = "arn:aws:dynamodb:*:*:table/${local.name_prefix}-*"
      },
      {
        Sid      = "SNSPublish"
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = "arn:aws:sns:*:*:${local.name_prefix}-*"
      },
      {
        Sid      = "SecretsAccess"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "arn:aws:secretsmanager:*:*:secret:${local.name_prefix}/*"
      }
    ]
  })
}

resource "aws_iam_role" "autoscaling_role" {
  name        = "${local.name_prefix}-autoscaling-role"
  description = "Permite a Auto Scaling ajustar las tareas ECS Fargate"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "application-autoscaling.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "autoscaling_role_policy" {
  role       = aws_iam_role.autoscaling_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceAutoscaleRole"
}

resource "aws_iam_role" "rds_monitoring" {
  name = "${local.name_prefix}-rds-monitoring-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_iam_role" "s3_replication" {
  name = "${local.name_prefix}-s3-replication-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = { Name = "${local.name_prefix}-s3-replication-role" }
}

resource "aws_iam_role_policy" "s3_replication" {
  name = "${local.name_prefix}-s3-replication-policy"
  role = aws_iam_role.s3_replication.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
        Resource = ["arn:aws:s3:::*"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObjectVersionForReplication", "s3:GetObjectVersionAcl", "s3:GetObjectVersionTagging"]
        Resource = ["arn:aws:s3:::*/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ReplicateObject", "s3:ReplicateDelete", "s3:ReplicateTags"]
        Resource = ["arn:aws:s3:::*/*"]
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# KMS CMK compartida (secrets, cloudtrail, logs cifrados de otros modulos)
# ---------------------------------------------------------------------------
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
      {
        Sid       = "Allow CloudTrail"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
        Resource  = "*"
      }
    ]
  })
  tags = { Name = "${local.name_prefix}-kms-secrets" }
}

# ---------------------------------------------------------------------------
# Contenedores de Secrets Manager (metadatos -- los valores de db_credentials
# se cargan desde modules/observability, que si tiene el endpoint de RDS)
# ---------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${local.name_prefix}/rds/credentials"
  description             = "Credenciales de RDS PostgreSQL para el monolito SEGAT"
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = 7
  tags                    = { Name = "${local.name_prefix}-secret-rds" }
}

resource "aws_secretsmanager_secret_rotation" "db_credentials" {
  count               = var.enable_secrets_rotation ? 1 : 0
  secret_id           = aws_secretsmanager_secret.db_credentials.id
  rotation_lambda_arn = "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:SecretsManagerRotation"
  rotation_rules {
    automatically_after_days = 30
  }
}

resource "aws_secretsmanager_secret" "cloudinary" {
  name        = "${local.name_prefix}/cloudinary"
  description = "Credenciales de Cloudinary para el proyecto SEGAT"
  kms_key_id  = aws_kms_key.secrets.arn
  tags        = { Name = "${local.name_prefix}-secret-cloudinary" }
}

resource "aws_secretsmanager_secret_rotation" "cloudinary" {
  count               = var.enable_secrets_rotation ? 1 : 0
  secret_id           = aws_secretsmanager_secret.cloudinary.id
  rotation_lambda_arn = "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:SecretsManagerRotation"
  rotation_rules {
    automatically_after_days = 30
  }
}

resource "aws_secretsmanager_secret" "jwt" {
  name        = "${local.name_prefix}/jwt"
  description = "Secretos JWT para autenticacion del proyecto SEGAT"
  kms_key_id  = aws_kms_key.secrets.arn
  tags        = { Name = "${local.name_prefix}-secret-jwt" }
}

resource "aws_secretsmanager_secret_rotation" "jwt" {
  count               = var.enable_secrets_rotation ? 1 : 0
  secret_id           = aws_secretsmanager_secret.jwt.id
  rotation_lambda_arn = "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:SecretsManagerRotation"
  rotation_rules {
    automatically_after_days = 30
  }
}

# Reemplaza al antiguo secreto "n8n" (webhooks) -- las notificaciones ya no
# pasan por n8n, se mandan por SMTP directo desde el backend.
resource "aws_secretsmanager_secret" "smtp" {
  name        = "${local.name_prefix}/smtp"
  description = "Credenciales SMTP para el envio de notificaciones por email"
  kms_key_id  = aws_kms_key.secrets.arn
  tags        = { Name = "${local.name_prefix}-secret-smtp" }
}

resource "aws_secretsmanager_secret_rotation" "smtp" {
  count               = var.enable_secrets_rotation ? 1 : 0
  secret_id           = aws_secretsmanager_secret.smtp.id
  rotation_lambda_arn = "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:SecretsManagerRotation"
  rotation_rules {
    automatically_after_days = 30
  }
}

