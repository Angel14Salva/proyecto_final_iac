# =============================================================================
# modules/monitoring/main.tf
# Stack PLG (Prometheus, Loki, Grafana) en ECS Fargate con persistencia EFS
# =============================================================================

# --- 1. Cloud Map (Service Discovery) ---
resource "aws_service_discovery_private_dns_namespace" "monitoring" {
  name        = "segat.local"
  description = "Namespace para descubrimiento de servicios de monitoreo"
  vpc         = var.vpc_id
}

# --- 2. ECR Repositories ---
resource "aws_ecr_repository" "prometheus" {
  name                 = "${var.project_name}/prometheus"
  image_tag_mutability = "MUTABLE"
  tags                 = { Name = "${var.project_name}-ecr-prometheus" }
}

resource "aws_ecr_repository" "loki" {
  name                 = "${var.project_name}/loki"
  image_tag_mutability = "MUTABLE"
  tags                 = { Name = "${var.project_name}-ecr-loki" }
}

resource "aws_ecr_repository" "grafana" {
  name                 = "${var.project_name}/grafana"
  image_tag_mutability = "MUTABLE"
  tags                 = { Name = "${var.project_name}-ecr-grafana" }
}

# --- 3. Log Groups ---
resource "aws_cloudwatch_log_group" "prometheus" {
  name              = "/ecs/${var.project_name}/prometheus"
  retention_in_days = 7
  kms_key_id        = var.kms_secrets_key_arn
}

resource "aws_cloudwatch_log_group" "loki" {
  name              = "/ecs/${var.project_name}/loki"
  retention_in_days = 7
  kms_key_id        = var.kms_secrets_key_arn
}

resource "aws_cloudwatch_log_group" "grafana" {
  name              = "/ecs/${var.project_name}/grafana"
  retention_in_days = 7
  kms_key_id        = var.kms_secrets_key_arn
}

# --- 4. Security Groups ---
resource "aws_security_group" "monitoring" {
  name        = "${var.project_name}-sg-monitoring"
  description = "Puertos para Grafana (3000), Prometheus (9090) y Loki (3100)"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Grafana publico
  }

  ingress {
    from_port = 9090
    to_port   = 9090
    protocol  = "tcp"
    self      = true # Para que se comuniquen entre si
  }

  ingress {
    from_port = 3100
    to_port   = 3100
    protocol  = "tcp"
    self      = true
  }

  # Permitir que el backend (ECS) envie logs a Loki
  ingress {
    from_port   = 3100
    to_port     = 3100
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Todo el trafico de la VPC
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-sg-monitoring" }
}

resource "aws_security_group" "efs" {
  name        = "${var.project_name}-sg-efs-monitoring"
  description = "Permitir NFS a los volumenes EFS de monitoreo"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.monitoring.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-sg-efs-monitoring" }
}

# --- 5. EFS File Systems ---
resource "aws_efs_file_system" "prometheus" {
  creation_token = "${var.project_name}-efs-prometheus"
  encrypted      = true
  tags           = { Name = "${var.project_name}-efs-prometheus" }
}

resource "aws_efs_mount_target" "prometheus_a" {
  file_system_id  = aws_efs_file_system.prometheus.id
  subnet_id       = var.subnet_private_a_id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_mount_target" "prometheus_b" {
  file_system_id  = aws_efs_file_system.prometheus.id
  subnet_id       = var.subnet_private_b_id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_file_system" "loki" {
  creation_token = "${var.project_name}-efs-loki"
  encrypted      = true
  tags           = { Name = "${var.project_name}-efs-loki" }
}

resource "aws_efs_mount_target" "loki_a" {
  file_system_id  = aws_efs_file_system.loki.id
  subnet_id       = var.subnet_private_a_id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_mount_target" "loki_b" {
  file_system_id  = aws_efs_file_system.loki.id
  subnet_id       = var.subnet_private_b_id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_file_system" "grafana" {
  creation_token = "${var.project_name}-efs-grafana"
  encrypted      = true
  tags           = { Name = "${var.project_name}-efs-grafana" }
}

resource "aws_efs_mount_target" "grafana_a" {
  # Grafana estara en public subnets, pero el mount target puede estar ahi o en private.
  # Lo ponemos en public subnets para que coincida con donde corre la tarea.
  file_system_id  = aws_efs_file_system.grafana.id
  subnet_id       = var.subnet_public_a_id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_mount_target" "grafana_b" {
  file_system_id  = aws_efs_file_system.grafana.id
  subnet_id       = var.subnet_public_b_id
  security_groups = [aws_security_group.efs.id]
}

# --- 6. Secrets Manager ---
resource "aws_secretsmanager_secret" "grafana_admin" {
  name        = "${var.project_name}/grafana/admin"
  description = "Password de Grafana Admin"
  kms_key_id  = var.kms_secrets_key_arn
}

resource "aws_secretsmanager_secret_version" "grafana_admin" {
  secret_id     = aws_secretsmanager_secret.grafana_admin.id
  secret_string = var.grafana_admin_password
}

# --- 7. Prometheus ECS ---
resource "aws_service_discovery_service" "prometheus" {
  name = "prometheus"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.monitoring.id
    dns_records {
      ttl  = 60
      type = "A"
    }
  }
}

resource "aws_ecs_task_definition" "prometheus" {
  family                   = "${var.project_name}-prometheus"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn            = aws_iam_role.monitoring_task_role.arn

  volume {
    name = "prometheus_data"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.prometheus.id
      root_directory = "/"
    }
  }

  container_definitions = jsonencode([{
    name         = "prometheus"
    image        = "${aws_ecr_repository.prometheus.repository_url}:latest"
    essential    = true
    portMappings = [{ containerPort = 9090, protocol = "tcp" }]
    mountPoints = [{
      sourceVolume  = "prometheus_data"
      containerPath = "/prometheus"
      readOnly      = false
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.prometheus.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "prometheus"
      }
    }
  }])
}

resource "aws_ecs_service" "prometheus" {
  name            = "${var.project_name}-prometheus"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.prometheus.arn
  desired_count   = var.prometheus_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [var.subnet_private_a_id, var.subnet_private_b_id]
    security_groups  = [aws_security_group.monitoring.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.prometheus.arn
  }
}

# --- 8. Loki ECS ---
resource "aws_service_discovery_service" "loki" {
  name = "loki"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.monitoring.id
    dns_records {
      ttl  = 60
      type = "A"
    }
  }
}

resource "aws_ecs_task_definition" "loki" {
  family                   = "${var.project_name}-loki"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn            = aws_iam_role.monitoring_task_role.arn

  volume {
    name = "loki_data"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.loki.id
      root_directory = "/"
    }
  }

  container_definitions = jsonencode([{
    name         = "loki"
    image        = "${aws_ecr_repository.loki.repository_url}:latest"
    essential    = true
    portMappings = [{ containerPort = 3100, protocol = "tcp" }]
    mountPoints = [{
      sourceVolume  = "loki_data"
      containerPath = "/loki"
      readOnly      = false
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.loki.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "loki"
      }
    }
  }])
}

resource "aws_ecs_service" "loki" {
  name            = "${var.project_name}-loki"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.loki.arn
  desired_count   = var.loki_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [var.subnet_private_a_id, var.subnet_private_b_id]
    security_groups  = [aws_security_group.monitoring.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.loki.arn
  }
}

# --- 9. Grafana ECS ---
resource "aws_ecs_task_definition" "grafana" {
  family                   = "${var.project_name}-grafana"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn            = aws_iam_role.monitoring_task_role.arn

  volume {
    name = "grafana_data"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.grafana.id
      root_directory = "/"
    }
  }

  container_definitions = jsonencode([{
    name         = "grafana"
    image        = "${aws_ecr_repository.grafana.repository_url}:latest"
    essential    = true
    portMappings = [{ containerPort = 3000, protocol = "tcp" }]

    environment = [
      { name = "GF_SECURITY_ADMIN_USER", value = "admin" },
      { name = "GF_SERVER_ROOT_URL", value = "http://localhost:3000" },
      { name = "GF_INSTALL_PLUGINS", value = "" }
    ]

    secrets = [{
      name      = "GF_SECURITY_ADMIN_PASSWORD"
      valueFrom = aws_secretsmanager_secret.grafana_admin.arn
    }]

    mountPoints = [{
      sourceVolume  = "grafana_data"
      containerPath = "/var/lib/grafana"
      readOnly      = false
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.grafana.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "grafana"
      }
    }
  }])
}

resource "aws_ecs_service" "grafana" {
  name            = "${var.project_name}-grafana"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.grafana.arn
  desired_count   = var.grafana_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    # Grafana en public subnets para acceder directamente
    subnets          = [var.subnet_public_a_id, var.subnet_public_b_id]
    security_groups  = [aws_security_group.monitoring.id]
    assign_public_ip = true
  }
}
