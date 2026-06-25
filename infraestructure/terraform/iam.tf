# =============================================================================
# iam.tf — FASE 2: Roles IAM con principio de minimo privilegio
# =============================================================================

resource "aws_iam_role" "ecs_execution_role" {
  name        = "${var.project_name}-ecs-execution-role"
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
  name = "${var.project_name}-ecs-execution-secrets"
  role = aws_iam_role.ecs_execution_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsManagerAccess"
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        # Restringido solo a los secrets del proyecto (evita acceso a toda la cuenta)
        Resource = [
          "arn:aws:secretsmanager:*:*:secret:${var.project_name}/*",
        ]
      },
      {
        Sid    = "SSMParametersAccess"
        Effect = "Allow"
        Action = ["ssm:GetParameters", "ssm:GetParameter"]
        # Restringido al path del proyecto en Parameter Store
        Resource = "arn:aws:ssm:*:*:parameter/${var.project_name}/*"
      }
    ]
  })
}

resource "aws_iam_role" "ecs_task_role" {
  name        = "${var.project_name}-ecs-task-role"
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
  name = "${var.project_name}-ecs-task-permissions"
  role = aws_iam_role.ecs_task_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SQSAccess"
        Effect = "Allow"
        Action = ["sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        # Restringido a las colas del proyecto (antes era "*")
        Resource = [
          "arn:aws:sqs:*:*:${var.project_name}-*",
        ]
      },
      {
        Sid      = "S3ReportesAccess"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::${var.project_name}-reportes-*/*"
      },
      {
        Sid    = "DynamoDBAccess"
        Effect = "Allow"
        Action = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:UpdateItem", "dynamodb:Query", "dynamodb:Scan"]
        Resource = [
          "arn:aws:dynamodb:*:*:table/${var.project_name}-*",
          "arn:aws:dynamodb:*:*:table/${var.project_name}-*/index/*",
        ]
      },
      {
        Sid    = "SNSPublish"
        Effect = "Allow"
        Action = ["sns:Publish"]
        # Restringido a los topics del proyecto (antes era "*")
        Resource = "arn:aws:sns:*:*:${var.project_name}-*"
      },
      {
        Sid    = "SecretsAccess"
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = "arn:aws:secretsmanager:*:*:secret:${var.project_name}/*"
      }
    ]
  })
}

resource "aws_iam_role" "autoscaling_role" {
  name        = "${var.project_name}-autoscaling-role"
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

# =============================================================================
# RDS Enhanced Monitoring Role
# Requerido cuando monitoring_interval > 0 en aws_db_instance
# =============================================================================

resource "aws_iam_role" "rds_monitoring" {
  name        = "${var.project_name}-rds-enhanced-monitoring"
  description = "Permite a RDS enviar metricas de Enhanced Monitoring a CloudWatch"
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
