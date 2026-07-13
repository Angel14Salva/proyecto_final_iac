

# =============================================================================
# modules/compute/main.tf
# ECS Cluster + Fargate + ALB EXTERNO/INTERNO + Auto Scaling
#
# NOTA: se elimino aws_wafv2_web_acl_association.external de este archivo --
# duplicaba exactamente aws_wafv2_web_acl_association.alb en modules/firewall
# (mismo resource_arn + web_acl_arn). AWS solo permite una asociacion por
# recurso; la version que se conserva vive en modules/firewall.
# =============================================================================

data "aws_caller_identity" "current" {}

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
resource "aws_lb" "external" {
  name               = "${var.project_name}-alb-external"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.sg_alb_id]
  subnets            = [var.subnet_public_a_id, var.subnet_public_b_id]

  drop_invalid_header_fields = true

  enable_deletion_protection = true

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    prefix  = "alb"
    enabled = true
  }

  # Sin esto, Terraform solo espera a que exista el bucket (referenciado arriba),
  # no a que su policy/ownership controls esten aplicadas -- AWS rechaza
  # habilitar access_logs si eso todavia no esta listo ("Access Denied for bucket")
  depends_on = [aws_s3_bucket_policy.alb_logs, aws_s3_bucket_ownership_controls.alb_logs]

  tags = { Name = "${var.project_name}-alb-external" }
}

resource "aws_lb" "internal" {
  name               = "${var.project_name}-alb-internal"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [var.sg_ecs_tasks_id]
  subnets            = [var.subnet_private_a_id, var.subnet_private_b_id]

  drop_invalid_header_fields = true
  enable_deletion_protection = true

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    prefix  = "alb-internal"
    enabled = true
  }

  depends_on = [aws_s3_bucket_policy.alb_logs, aws_s3_bucket_ownership_controls.alb_logs]

  tags = { Name = "${var.project_name}-alb-internal" }
}

resource "aws_lb_target_group" "internal" {
  # Mismo motivo que aws_lb_target_group.ecs: el backend sirve HTTP plano,
  # no HTTPS, en el puerto 8080.
  name        = "${var.project_name}-tg-internal"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  health_check {
    path                = "/actuator/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }
  tags = { Name = "${var.project_name}-tg-internal" }
}

resource "aws_lb_listener" "internal_http" {
  load_balancer_arn = aws_lb.internal.arn
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

resource "aws_lb_listener" "internal_https" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.internal.arn
  }
}

# S3 bucket para los access logs del ALB
# Los access logs del ALB los escribe el servicio de ELB de AWS, no IAM roles
resource "aws_s3_bucket" "alb_logs" {
  # checkov:skip=CKV_AWS_145: ELB access logs NO soportan SSE-KMS (ver
  # aws_s3_bucket_server_side_encryption_configuration.alb_logs mas abajo) --
  # restriccion documentada de AWS, no de permisos. Checkov evalua este check
  # sobre el bucket en si, no sobre el recurso de encriptacion separado.
  bucket        = "${var.project_name}-alb-logs-${var.environment}-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
  tags          = { Name = "${var.project_name}-s3-alb-logs" }
}

resource "aws_s3_bucket_replication_configuration" "alb_logs" {
  count      = var.enable_s3_replication ? 1 : 0
  depends_on = [aws_s3_bucket_versioning.alb_logs]
  role       = var.s3_replication_role_arn
  bucket     = aws_s3_bucket.alb_logs.id
  rule {
    id     = "replicacion-alb-logs"
    status = "Enabled"
    destination {
      bucket        = "arn:aws:s3:::${var.replication_bucket_alb}"
      storage_class = "STANDARD"
    }
  }
}

resource "aws_s3_bucket_notification" "alb_logs" {
  bucket      = aws_s3_bucket.alb_logs.id
  eventbridge = true
}

# Desde abril 2023, los buckets S3 nuevos se crean con "Bucket owner enforced"
# (ACLs deshabilitadas) por defecto. La bucket policy de alb_logs exige que el
# ELB escriba con el ACL "bucket-owner-full-control" -- con las ACLs
# deshabilitadas esa condicion nunca se cumple y AWS rechaza el acceso, sin
# importar que la policy y el cifrado esten bien. Esto reactiva las ACLs.
resource "aws_s3_bucket_ownership_controls" "alb_logs" {
  # checkov:skip=CKV2_AWS_65: Las ACLs deben quedar habilitadas a proposito
  # -- el servicio de ELB exige escribir con "bucket-owner-full-control"
  # (ver comentario arriba). Deshabilitarlas rompe la entrega de logs.
  bucket = aws_s3_bucket.alb_logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_versioning" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  rule {
    apply_server_side_encryption_by_default {
      # A diferencia de CloudTrail/SNS, los access logs de ELB NO soportan
      # SSE-KMS (ni con la key administrada por AWS ni con una propia) --
      # es una restriccion documentada de AWS, no un tema de permisos. Por
      # eso el intento anterior (darle permisos KMS al servicio) no funciono:
      # ModifyLoadBalancerAttributes rechaza cualquier bucket cifrado con KMS.
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_logging" "alb_logs" {
  bucket        = aws_s3_bucket.alb_logs.id
  target_bucket = aws_s3_bucket.alb_logs.id
  target_prefix = "access-logs/"
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  rule {
    id     = "expire-alb-logs"
    status = "Enabled"
    filter {}
    expiration { days = 90 }
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket                  = aws_s3_bucket.alb_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Politica que permite al servicio ELB de AWS escribir los access logs
data "aws_elb_service_account" "main" {}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { AWS = data.aws_elb_service_account.main.arn }
        Action    = "s3:PutObject"
        # "alb*" cubre tanto el prefix "alb" (aws_lb.external) como
        # "alb-internal" (aws_lb.internal) -- antes solo alcanzaba a "alb",
        # asi que el ALB interno nunca podia escribir sus logs
        Resource = "${aws_s3_bucket.alb_logs.arn}/alb*/AWSLogs/*"
      },
      {
        Effect    = "Allow"
        Principal = { Service = "delivery.logs.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.alb_logs.arn}/alb*/AWSLogs/*"
        Condition = { StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" } }
      },
      {
        Effect    = "Allow"
        Principal = { Service = "delivery.logs.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.alb_logs.arn
      }
    ]
  })
}

resource "aws_lb_target_group" "ecs" {
  # El backend Spring Boot sirve HTTP plano en 8080 (no tiene server.ssl
  # configurado) -- el cifrado termina en el ALB, y ALB->target dentro de
  # la VPC privada viaja como HTTP. Un target group HTTPS aqui hace que el
  # ALB intente un handshake TLS contra un puerto sin TLS, y el health
  # check nunca deja de dar timeout (Target.Timeout), aunque el contenedor
  # este corriendo perfectamente.
  name        = "${var.project_name}-tg-ecs"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
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
# ELBSecurityPolicy-TLS13-1-2-2021-06 soporta TLS 1.2 y 1.3, descarta cifrados debiles
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
  kms_key_id        = var.kms_secrets_key_arn
  tags              = { Name = "${var.project_name}-ecs-logs" }
}

resource "aws_ecs_task_definition" "segat_backend" {
  family                   = "${var.project_name}-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode([{
    name         = "${var.project_name}-backend"
    image        = "${aws_ecr_repository.segat_backend.repository_url}:latest"
    essential    = true
    portMappings = [{ containerPort = 8080, protocol = "tcp" }]

    # Variables de entorno no sensibles
    environment = [
      { name = "APP_ENV", value = var.environment },
      { name = "SERVER_PORT", value = "8080" },
      { name = "PROJECT_NAME", value = var.project_name },
      { name = "SPRING_PROFILES_ACTIVE", value = "prod" },
      # Hibernate — nunca create-drop en produccion
      { name = "SPRING_JPA_HIBERNATE_DDL_AUTO", value = var.hibernate_ddl_auto },
      # Mensajeria AWS (SQS/SNS/DynamoDB) — no son secretos, son
      # identificadores de recursos, igual que el resto de esta lista
      { name = "AWS_REGION", value = var.aws_region },
      { name = "SQS_REPORTES_URL", value = var.sqs_reportes_queue_url },
      { name = "SQS_NOTIFICACIONES_URL", value = var.sqs_notificaciones_queue_url },
      { name = "SNS_NEGOCIO_ARN", value = var.sns_negocio_topic_arn },
      { name = "DYNAMODB_GPS_TABLE", value = var.dynamodb_gps_table_name },
      { name = "DYNAMODB_NOTIFICATIONS_TABLE", value = var.dynamodb_notifications_table_name },
      # SMTP -- host/puerto/from no son secretos, solo las credenciales lo son
      { name = "SMTP_HOST", value = var.smtp_host },
      { name = "SMTP_PORT", value = var.smtp_port },
      { name = "MAIL_FROM", value = var.mail_from }
    ]

    # Secrets inyectados desde Secrets Manager — nunca en texto plano
    secrets = [
      { name = "DATABASE_URL", valueFrom = "${var.secret_db_credentials_arn}:url::" },
      { name = "CLOUDINARY_CLOUD_NAME", valueFrom = "${var.secret_cloudinary_arn}:cloud_name::" },
      { name = "CLOUDINARY_API_KEY", valueFrom = "${var.secret_cloudinary_arn}:api_key::" },
      { name = "CLOUDINARY_API_SECRET", valueFrom = "${var.secret_cloudinary_arn}:api_secret::" },
      { name = "JWT_SECRET", valueFrom = "${var.secret_jwt_arn}:secret::" },
      { name = "JWT_EXPIRATION", valueFrom = "${var.secret_jwt_arn}:expiration::" },
      { name = "JWT_REFRESH_EXPIRATION", valueFrom = "${var.secret_jwt_arn}:refresh_expiration::" },
      { name = "SMTP_USERNAME", valueFrom = "${var.secret_smtp_arn}:username::" },
      { name = "SMTP_PASSWORD", valueFrom = "${var.secret_smtp_arn}:password::" }
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
    subnets          = [var.subnet_private_a_id, var.subnet_private_b_id]
    security_groups  = [var.sg_ecs_tasks_id]
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
    aws_lb_listener.http_redirect,
    aws_lb_listener.https,
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

