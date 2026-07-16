# =============================================================================
# modules/monitoring/iam.tf
# =============================================================================

resource "aws_iam_role" "monitoring_task_role" {
  name        = "${var.project_name}-monitoring-task-role"
  description = "Role para las tareas de monitoreo (Prometheus, Loki, Grafana)"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = { Name = "${var.project_name}-monitoring-task-role" }
}

# Permisos para que Prometheus pueda hacer Service Discovery de ECS
resource "aws_iam_role_policy" "prometheus_ecs_sd" {
  name = "${var.project_name}-prometheus-ecs-sd"
  role = aws_iam_role.monitoring_task_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecs:ListClusters",
        "ecs:ListTasks",
        "ecs:DescribeTask",
        "ecs:DescribeTasks",
        "ec2:DescribeInstances",
        "ecs:DescribeContainerInstances",
        "ecs:DescribeServices",
        "ecs:DescribeTaskDefinition"
      ]
      Resource = "*"
    }]
  })
}

# Permisos para que Grafana pueda leer secretos (admin password)
resource "aws_iam_role_policy" "grafana_secrets" {
  name = "${var.project_name}-grafana-secrets"
  role = aws_iam_role.monitoring_task_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = "arn:aws:secretsmanager:*:*:secret:${var.project_name}/grafana/*"
    }]
  })
}

# Permisos generales de CloudWatch para Logs
resource "aws_iam_role_policy_attachment" "monitoring_cloudwatch" {
  role       = aws_iam_role.monitoring_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}
