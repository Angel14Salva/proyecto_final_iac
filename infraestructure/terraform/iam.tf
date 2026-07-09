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
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "ssm:GetParameters"]
      Resource = "arn:aws:secretsmanager:*:*:secret:segat/*"
    }]
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
        Sid      = "SQSAccess"
        Effect   = "Allow"
        Action   = ["sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = "arn:aws:sqs:*:*:segat-*"
      },
      {
        Sid      = "S3ReportesAccess"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::${var.project_name}-reportes-*/*"
      },
      {
        Sid      = "DynamoDBAccess"
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:UpdateItem", "dynamodb:Query", "dynamodb:Scan"]
        Resource = "arn:aws:dynamodb:*:*:table/${var.project_name}-*"
      },
      {
        Sid      = "SNSPublish"
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = "arn:aws:sns:*:*:segat-*"
      },
      {
        Sid      = "SecretsAccess"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
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

resource "aws_iam_role" "rds_monitoring" {
  name = "${var.project_name}-rds-monitoring-role"
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
  name = "${var.project_name}-s3-replication-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = { Name = "${var.project_name}-s3-replication-role" }
}

resource "aws_iam_role_policy" "s3_replication" {
  name = "${var.project_name}-s3-replication-policy"
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
        Resource = ["arn:aws:s3:::/"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ReplicateObject", "s3:ReplicateDelete", "s3:ReplicateTags"]
        Resource = ["arn:aws:s3:::/"]
      }
    ]
  })
}
