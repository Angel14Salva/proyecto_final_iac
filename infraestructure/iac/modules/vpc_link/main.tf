
# =============================================================================
# modules/vpc_link/main.tf
# VPC Link para API Gateway -> NLB -> ALB interno (ver comentario original
# en el vpc-link.tf monolitico: el ALB interno es privado y API Gateway no
# puede alcanzarlo directamente).
# =============================================================================

resource "aws_security_group" "internal_nlb" {
  name        = "${var.project_name}-sg-internal-nlb"
  description = "Trafico hacia el NLB que conecta API Gateway (VPC Link) con el ALB interno"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS desde la VPC (ENIs administradas por API Gateway VPC Link)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Salida hacia el ALB interno"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = { Name = "${var.project_name}-sg-internal-nlb" }
}

# El ALB interno hoy solo acepta 443 desde su propio security group
# (modules.networking.sg_ecs_tasks). Se agrega esta regla para que tambien
# acepte trafico desde el nuevo NLB, sin tocar las reglas existentes.
resource "aws_security_group_rule" "internal_alb_from_nlb" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = var.sg_ecs_tasks_id
  source_security_group_id = aws_security_group.internal_nlb.id
  description              = "HTTPS desde el NLB del VPC Link (API Gateway)"
}

resource "aws_lb" "internal_nlb" {
  name               = "${var.project_name}-nlb-internal"
  internal           = true
  load_balancer_type = "network"
  security_groups    = [aws_security_group.internal_nlb.id]
  subnets            = [var.subnet_private_a_id, var.subnet_private_b_id]

  enable_deletion_protection       = true
  enable_cross_zone_load_balancing = true

  # Prefijo "alb-internal-nlb" para reutilizar la bucket policy de alb_logs
  # (modules.compute) que ya autoriza el prefijo "alb*" -- sin tocar esa policy.
  access_logs {
    bucket  = var.alb_logs_bucket_id
    prefix  = "alb-internal-nlb"
    enabled = true
  }

  tags = { Name = "${var.project_name}-nlb-internal" }
}

# target_type = "alb": el NLB reenvia las conexiones TCP directamente al
# ALB interno existente (que sigue terminando TLS y balanceando hacia ECS).
resource "aws_lb_target_group" "internal_nlb" {
  name        = "${var.project_name}-tg-nlb-to-alb"
  port        = 443
  protocol    = "TCP"
  target_type = "alb"
  vpc_id      = var.vpc_id

  health_check {
    protocol            = "HTTPS"
    path                = "/actuator/health"
    port                = "443"
    interval            = 30
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = { Name = "${var.project_name}-tg-nlb-to-alb" }
}

resource "aws_lb_target_group_attachment" "internal_nlb_to_alb" {
  target_group_arn = aws_lb_target_group.internal_nlb.arn
  target_id        = var.alb_internal_arn
  port             = 443
}

resource "aws_lb_listener" "internal_nlb" {
  load_balancer_arn = aws_lb.internal_nlb.arn
  port              = 443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.internal_nlb.arn
  }
}

resource "aws_api_gateway_vpc_link" "internal" {
  name        = "${var.project_name}-vpc-link-internal"
  description = "Conecta API Gateway con el ALB interno via el NLB de arriba"
  target_arns = [aws_lb.internal_nlb.arn]
}
