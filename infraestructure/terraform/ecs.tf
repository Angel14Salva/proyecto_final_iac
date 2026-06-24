# =============================================================================
# ecs.tf — FASE 3: Computo ECS — Corazon del sistema SEGAT
# ECS Cluster + Fargate + ALB EXTERNO + Auto Scaling
# =============================================================================

resource "aws_ecr_repository" "segat_backend" {
  name                 = "${var.project_name}/backend"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration {
    encryption_type = "KMS"
  }
  tags = { Name = "${var.project_name}-ecr-backend" }
}

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  tags = { Name = "${var.project_name}-ecs-cluster" }
}

# ALB EXTERNO — accesible desde internet, en subredes PÚBLICAS
# Corrección: era internal=true en subredes privadas, bloqueando todo el tráfico externo
resource "aws_lb" "external" {
  name               = "${var.project_name}-alb-external"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  tags               = { Name = "${var.project_name}-alb-external" }
}

resource "aws_lb_target_group" "ecs" {
  name        = "${var.project_name}-tg-ecs"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    # Corrección: /health no existe en el backend. Spring Actuator expone /actuator/health
    path                = "/actuator/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }
  tags = { Name = "${var.project_name}-tg-ecs" }
}

# Listener HTTP en puerto 80 — redirige a HTTPS
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.external.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Listener HTTPS en puerto 443
# Nota: para HTTPS se necesita un certificado ACM. Si no tienes uno,
# puedes usar el listener HTTP apuntando directamente al TG mientras pruebas.
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.external.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs.arn
  }
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}/backend"
  retention_in_days = 365
  tags              = { Name = "${var.project_name}-ecs-logs" }
}

resource "aws_ecs_task_definition" "segat_backend" {
  family                   = "${var.project_name}-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([{
    name      = "${var.project_name}-backend"
    image     = "${aws_ecr_repository.segat_backend.repository_url}:latest"
    essential = true
    portMappings = [{ containerPort = 8080, protocol = "tcp" }]

    # Variables de entorno no sensibles
    environment = [
      { name = "APP_ENV",                value = var.environment },
      { name = "SERVER_PORT",            value = "8080" },
      { name = "PROJECT_NAME",           value = var.project_name },
      { name = "SPRING_PROFILES_ACTIVE", value = "prod" },
      # Hibernate — nunca create-drop en produccion
      { name = "SPRING_JPA_HIBERNATE_DDL_AUTO", value = "validate" }
    ]

    # Secrets inyectados desde Secrets Manager — nunca en texto plano
    secrets = [
      { name = "DATABASE_URL",           valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:url::" },
      { name = "CLOUDINARY_CLOUD_NAME",  valueFrom = "${aws_secretsmanager_secret.cloudinary.arn}:cloud_name::" },
      { name = "CLOUDINARY_API_KEY",     valueFrom = "${aws_secretsmanager_secret.cloudinary.arn}:api_key::" },
      { name = "CLOUDINARY_API_SECRET",  valueFrom = "${aws_secretsmanager_secret.cloudinary.arn}:api_secret::" },
      { name = "JWT_SECRET",             valueFrom = "${aws_secretsmanager_secret.jwt.arn}:secret::" },
      { name = "JWT_EXPIRATION",         valueFrom = "${aws_secretsmanager_secret.jwt.arn}:expiration::" },
      { name = "JWT_REFRESH_EXPIRATION", valueFrom = "${aws_secretsmanager_secret.jwt.arn}:refresh_expiration::" },
      { name = "N8N_NEW_REPORT",         valueFrom = "${aws_secretsmanager_secret.n8n.arn}:new_report::" },
      { name = "N8N_NEW_TASK",           valueFrom = "${aws_secretsmanager_secret.n8n.arn}:new_task::" }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:8080/actuator/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
  }])

  tags = { Name = "${var.project_name}-task-definition" }
}

resource "aws_ecs_service" "segat_backend" {
  name            = "${var.project_name}-backend-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.segat_backend.arn
  desired_count   = var.ecs_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs.arn
    container_name   = "${var.project_name}-backend"
    container_port   = 8080
  }

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  depends_on = [
    aws_lb_listener.https,
    aws_lb_listener.http_redirect,
    aws_iam_role_policy_attachment.ecs_execution_role_policy
  ]

  tags = { Name = "${var.project_name}-ecs-service" }
}

resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = var.ecs_max_count
  min_capacity       = var.ecs_min_count
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.segat_backend.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "scale_cpu" {
  name               = "${var.project_name}-scale-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace
  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
