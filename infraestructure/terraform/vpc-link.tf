
# =============================================================================
# vpc-link.tf — VPC Link para API Gateway
#
# PROBLEMA: aws_lb.internal (ecs.tf) tiene internal = true en subredes
# privadas, asi que su DNS no es alcanzable desde API Gateway (que vive
# fuera de la VPC). La integracion HTTP_PROXY directa a su DNS name
# (apigateway.tf) fallaba en tiempo de ejecucion.
#
# SOLUCION: API Gateway REST API solo puede conectarse a recursos privados
# via VPC Link -> Network Load Balancer. Como el ALB ya existe y tiene toda
# la logica (TLS, target group, health checks), se usa la funcionalidad de
# AWS "ALB como target de un NLB" (target_type = "alb") en vez de duplicar
# el balanceo de carga: el NLB solo hace de puente TCP hacia el ALB interno.
# =============================================================================

resource "aws_security_group" "internal_nlb" {
  name        = "${var.project_name}-sg-internal-nlb"
  description = "Trafico hacia el NLB que conecta API Gateway (VPC Link) con el ALB interno"
  vpc_id      = aws_vpc.main.id

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
# (aws_security_group.ecs_tasks, ver ecs.tf). Se agrega esta regla para que
# tambien acepte trafico desde el nuevo NLB, sin tocar las reglas existentes.
resource "aws_security_group_rule" "internal_alb_from_nlb" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ecs_tasks.id
  source_security_group_id = aws_security_group.internal_nlb.id
  description               = "HTTPS desde el NLB del VPC Link (API Gateway)"
}

resource "aws_lb" "internal_nlb" {
  name               = "${var.project_name}-nlb-internal"
  internal           = true
  load_balancer_type = "network"
  security_groups    = [aws_security_group.internal_nlb.id]
  subnets            = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  enable_deletion_protection = true

  tags = { Name = "${var.project_name}-nlb-internal" }
}

# target_type = "alb": el NLB reenvia las conexiones TCP directamente al
# ALB interno existente (que sigue terminando TLS y balanceando hacia ECS).
resource "aws_lb_target_group" "internal_nlb" {
  name        = "${var.project_name}-tg-nlb-to-alb"
  port        = 443
  protocol    = "TCP"
  target_type = "alb"
  vpc_id      = aws_vpc.main.id

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
  target_id        = aws_lb.internal.arn
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

