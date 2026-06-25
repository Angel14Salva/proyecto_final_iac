# =============================================================================
# vpc.tf — FASE 1: Fundacion de Red
# VPC Multi-AZ, subredes, NAT Gateway, Security Groups
# =============================================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "${var.project_name}-vpc" }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_public_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false
  tags = { Name = "${var.project_name}-subnet-public-a", Tier = "Public" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_public_b_cidr
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false
  tags = { Name = "${var.project_name}-subnet-public-b", Tier = "Public" }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_private_a_cidr
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = { Name = "${var.project_name}-subnet-private-a", Tier = "Private-Compute", AZ = "AZ-A" }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_private_b_cidr
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = { Name = "${var.project_name}-subnet-private-b", Tier = "Private-Compute", AZ = "AZ-B" }
}

resource "aws_subnet" "private_c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_private_c_cidr
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = { Name = "${var.project_name}-subnet-private-c", Tier = "Private-Data", AZ = "AZ-A" }
}

resource "aws_subnet" "private_c2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_private_c2_cidr
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = { Name = "${var.project_name}-subnet-private-c2", Tier = "Private-Data", AZ = "AZ-B" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-igw" }
}

resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]
  tags       = { Name = "${var.project_name}-eip-nat" }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id
  depends_on    = [aws_internet_gateway.main]
  tags          = { Name = "${var.project_name}-nat-gw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "${var.project_name}-rt-public" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
  tags = { Name = "${var.project_name}-rt-private" }
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
  name        = "${var.project_name}-sg-alb"
  description = "Trafico HTTP y HTTPS hacia el ALB"
  vpc_id      = aws_vpc.main.id
  ingress {
    description = "HTTPS desde internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Salida hacia los Fargate Tasks"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project_name}-sg-alb" }
}

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-sg-ecs-tasks"
  description = "Trafico hacia Fargate solo desde el ALB"
  vpc_id      = aws_vpc.main.id
  ingress {
    description     = "Puerto 8080 solo desde el ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  egress {
    description = "Salida a internet via NAT Gateway"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project_name}-sg-ecs-tasks" }
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-sg-rds"
  description = "PostgreSQL accesible solo desde los contenedores Fargate"
  vpc_id      = aws_vpc.main.id
  ingress {
    description     = "PostgreSQL solo desde ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }
  tags = { Name = "${var.project_name}-sg-rds" }
}

resource "aws_security_group" "redis" {
  name        = "${var.project_name}-sg-redis"
  description = "Redis accesible solo desde los contenedores Fargate"
  vpc_id      = aws_vpc.main.id
  ingress {
    description     = "Redis solo desde ECS"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }
  tags = { Name = "${var.project_name}-sg-redis" }
}

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-default-sg-bloqueado" }
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flowlogs/${var.project_name}"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.secrets.arn
  tags              = { Name = "${var.project_name}-vpc-flow-logs" }
}

resource "aws_flow_log" "main" {
  vpc_id          = aws_vpc.main.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.ecs_execution_role.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  tags            = { Name = "${var.project_name}-flow-log" }
}
