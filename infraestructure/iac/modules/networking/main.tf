

# =============================================================================
# modules/networking/main.tf
# VPC Multi-AZ, subredes, NAT Gateway, Security Groups
# =============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

resource "aws_vpc" "main" {
  # checkov:skip=CKV2_AWS_12: El security group por defecto SI esta bloqueado
  # -- ver aws_default_security_group.default (sin ingress/egress) mas abajo
  # en este archivo. Checkov no siempre traza esta asociacion en el grafo.
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "${local.name_prefix}-vpc" }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_public_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false
  tags                    = { Name = "${local.name_prefix}-subnet-public-a", Tier = "Public" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_public_b_cidr
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false
  tags                    = { Name = "${local.name_prefix}-subnet-public-b", Tier = "Public" }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_private_a_cidr
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = { Name = "${local.name_prefix}-subnet-private-a", Tier = "Private-Compute", AZ = "AZ-A" }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_private_b_cidr
  availability_zone = data.aws_availability_zones.available.names[1]
  tags              = { Name = "${local.name_prefix}-subnet-private-b", Tier = "Private-Compute", AZ = "AZ-B" }
}

resource "aws_subnet" "private_c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_private_c_cidr
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = { Name = "${local.name_prefix}-subnet-private-c", Tier = "Private-Data", AZ = "AZ-A" }
}

resource "aws_subnet" "private_c2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_private_c2_cidr
  availability_zone = data.aws_availability_zones.available.names[1]
  tags              = { Name = "${local.name_prefix}-subnet-private-c2", Tier = "Private-Data", AZ = "AZ-B" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name_prefix}-igw" }
}

resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]
  tags       = { Name = "${local.name_prefix}-eip-nat" }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id
  depends_on    = [aws_internet_gateway.main]
  tags          = { Name = "${local.name_prefix}-nat-gw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "${local.name_prefix}-rt-public" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
  tags = { Name = "${local.name_prefix}-rt-private" }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_c" {
  subnet_id      = aws_subnet.private_c.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_c2" {
  subnet_id      = aws_subnet.private_c2.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "alb" {
  # checkov:skip=CKV2_AWS_5: SI esta asociado -- a aws_lb.external y
  # aws_lb.internal (modules.compute, via var.sg_alb_id/var.sg_ecs_tasks_id).
  # Checkov no traza la asociacion porque el ALB vive en un modulo distinto.
  name        = "${local.name_prefix}-sg-alb"
  description = "Trafico HTTP y HTTPS hacia el ALB"
  vpc_id      = aws_vpc.main.id
  # checkov:skip=CKV_AWS_260: El puerto 80 desde 0.0.0.0/0 es a proposito --
  # CloudFront le habla al ALB por HTTP en /api/* (el ALB usa un certificado
  # autofirmado que CloudFront no puede validar en un origen custom). El
  # cliente real sigue viendo HTTPS de punta a punta via CloudFront.
  ingress {
    description = "HTTPS desde internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # CloudFront le habla al ALB por HTTP en /api/* (el ALB usa un certificado
  # autofirmado que CloudFront no puede validar en un origen custom). Sin
  # esta regla el puerto 80 nunca tuvo entrada abierta y las conexiones se
  # descartan en silencio (504 Gateway Timeout).
  ingress {
    description = "HTTP desde CloudFront (origin /api/*)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Salida hacia los Fargate Tasks (HTTPS via NLB/VPC Link)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # El backend Spring Boot sirve HTTP plano en 8080 (sin server.ssl), y los
  # target groups del ALB apuntan a ese puerto en HTTP -- sin esta regla,
  # el ALB nunca alcanza las tareas Fargate (ni para trafico real ni para
  # el health check), y da "Target.Timeout" aunque el contenedor este
  # sano y el target group ya sea HTTP.
  egress {
    description = "Salida hacia Fargate Tasks en 8080 (HTTP interno)"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${local.name_prefix}-sg-alb" }
}

# Sin reglas inline a proposito: modules.vpc_link agrega una regla de
# ingress a este mismo SG como recurso separado (aws_security_group_rule,
# para el NLB). Mezclar bloques inline con aws_security_group_rule externos
# sobre el mismo SG hace que Terraform intente borrar la regla externa en
# cada plan (no la reconoce como propia). Por eso TODAS las reglas de este
# SG viven como aws_security_group_rule separados, incluida esta.
resource "aws_security_group" "ecs_tasks" {
  # checkov:skip=CKV2_AWS_5: SI esta asociado -- a network_configuration del
  # servicio ECS (aws_ecs_service.segat_backend en modules.compute, via
  # var.sg_ecs_tasks_id) y al NLB del VPC Link (modules.vpc_link). Checkov no
  # traza la asociacion porque ambos viven en modulos distintos.
  name        = "${local.name_prefix}-sg-ecs-tasks"
  description = "Trafico hacia Fargate solo desde el ALB"
  vpc_id      = aws_vpc.main.id
  egress {
    description = "Salida a internet via NAT Gateway (ECR, Secrets Manager, APIs externas)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Sin estas dos reglas, las tareas Fargate no pueden alcanzar RDS ni Redis
  # aunque el security group de destino (rds/redis) SI acepte el trafico --
  # los security groups filtran salida y entrada por separado, y esa falta
  # de egress produce un SocketTimeoutException silencioso (no un
  # "connection refused"), dificil de distinguir de un problema de rutas.
  egress {
    description = "Salida hacia RDS PostgreSQL"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  egress {
    description = "Salida hacia ElastiCache Redis"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  tags = { Name = "${local.name_prefix}-sg-ecs-tasks" }
}

resource "aws_security_group_rule" "ecs_tasks_from_alb" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ecs_tasks.id
  source_security_group_id = aws_security_group.alb.id
  description              = "Puerto 8080 solo desde el ALB"
}

resource "aws_security_group" "rds" {
  # checkov:skip=CKV2_AWS_5: SI esta asociado -- a aws_db_instance.postgresql
  # (modules.database, via var.sg_rds_id). Checkov no traza la asociacion
  # porque el RDS vive en un modulo distinto al del security group.
  name        = "${local.name_prefix}-sg-rds"
  description = "PostgreSQL accesible solo desde los contenedores Fargate"
  vpc_id      = aws_vpc.main.id
  ingress {
    description     = "PostgreSQL solo desde ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }
  tags = { Name = "${local.name_prefix}-sg-rds" }
}

resource "aws_security_group" "redis" {
  # checkov:skip=CKV2_AWS_5: SI esta asociado -- a aws_elasticache_cluster.redis
  # (modules.database, via var.sg_redis_id). Checkov no traza la asociacion
  # porque el cluster Redis vive en un modulo distinto al del security group.
  name        = "${local.name_prefix}-sg-redis"
  description = "Redis accesible solo desde los contenedores Fargate"
  vpc_id      = aws_vpc.main.id
  ingress {
    description     = "Redis solo desde ECS"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }
  tags = { Name = "${local.name_prefix}-sg-redis" }
}

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name_prefix}-default-sg-bloqueado" }
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flowlogs/${local.name_prefix}"
  retention_in_days = 365
  kms_key_id        = var.kms_secrets_key_arn
  tags              = { Name = "${local.name_prefix}-vpc-flow-logs" }
}

resource "aws_flow_log" "main" {
  vpc_id          = aws_vpc.main.id
  traffic_type    = "ALL"
  iam_role_arn    = var.ecs_execution_role_arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  tags            = { Name = "${local.name_prefix}-flow-log" }
}

