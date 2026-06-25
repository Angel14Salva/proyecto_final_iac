# =============================================================================
# data.tf — FASE 4: Capa de datos
# RDS PostgreSQL + ElastiCache Redis + DynamoDB + S3
# =============================================================================

# =============================================================================
# KMS CMK — Clave maestra para la capa de datos
# Un CMK por servicio permite rotación y auditoría independiente
# =============================================================================
resource "aws_kms_key" "rds" {
  description             = "CMK para RDS PostgreSQL de ${var.project_name}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = { Name = "${var.project_name}-kms-rds" }
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.project_name}/rds"
  target_key_id = aws_kms_key.rds.key_id
}

resource "aws_kms_key" "redis" {
  description             = "CMK para ElastiCache Redis de ${var.project_name}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = { Name = "${var.project_name}-kms-redis" }
}

resource "aws_kms_alias" "redis" {
  name          = "alias/${var.project_name}/redis"
  target_key_id = aws_kms_key.redis.key_id
}


# =============================================================================
# RDS POSTGRESQL
# =============================================================================

resource "aws_db_subnet_group" "rds" {
  name       = "${var.project_name}-rds-subnet-group"
  subnet_ids = [aws_subnet.private_c.id, aws_subnet.private_c2.id]
  tags       = { Name = "${var.project_name}-rds-subnet-group" }
}

# Parameter group con query logging habilitado
resource "aws_db_parameter_group" "postgresql" {
  name   = "${var.project_name}-pg15-params"
  family = "postgres15"

  parameter {
    name  = "log_min_duration_statement"
    value = "1000" # loguear queries que tarden más de 1s
  }

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  tags = { Name = "${var.project_name}-pg-params" }
}

resource "aws_db_instance" "postgresql" {
  identifier        = "${var.project_name}-postgresql"
  engine            = "postgres"
  engine_version    = "15.7"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_type      = "gp2"

  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.postgresql.name

  backup_retention_period   = 7
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project_name}-postgresql-final-snapshot"
  deletion_protection       = true
  multi_az                  = true
  copy_tags_to_snapshot     = true

  iam_database_authentication_enabled = true

  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.rds.arn

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  auto_minor_version_upgrade = true

  ca_cert_identifier = "rds-ca-rsa2048-g1"

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  tags = { Name = "${var.project_name}-postgresql" }
}

# =============================================================================
# ELASTICACHE REDIS
# =============================================================================

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.project_name}-redis-subnet-group"
  subnet_ids = [aws_subnet.private_c.id, aws_subnet.private_c2.id]
  tags       = { Name = "${var.project_name}-redis-subnet-group" }
}

# Secret para el auth token de Redis
resource "aws_secretsmanager_secret" "redis_auth" {
  name        = "${var.project_name}/redis/auth-token"
  description = "Auth token para ElastiCache Redis (requerido con TLS)"
  kms_key_id  = aws_kms_key.redis.arn
  tags        = { Name = "${var.project_name}-secret-redis-auth" }
}

resource "aws_secretsmanager_secret_version" "redis_auth" {
  secret_id     = aws_secretsmanager_secret.redis_auth.id
  secret_string = var.redis_auth_token
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${var.project_name}-redis"
  description          = "Redis Multi-AZ HA para SEGAT"
  node_type            = "cache.t3.micro"
  num_cache_clusters   = 2
  parameter_group_name = "default.redis7"
  engine_version       = "7.0"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [aws_security_group.redis.id]
  automatic_failover_enabled = true
  multi_az_enabled           = true
  at_rest_encryption_enabled = true
  kms_key_id                 = aws_kms_key.redis.arn
  transit_encryption_enabled = true
  auth_token                 = var.redis_auth_token
  snapshot_retention_limit = 7
  tags                     = { Name = "${var.project_name}-redis-ha" }
}

# =============================================================================

resource "aws_dynamodb_table" "gps_locations" {
  name         = "${var.project_name}-gps-locations"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "reporte_id"
  range_key    = "timestamp"

  attribute {
    name = "reporte_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  ttl {
    attribute_name = "expiration_time"
    enabled        = true
  }

  tags = { Name = "${var.project_name}-dynamodb-gps" }

  point_in_time_recovery {
  enabled = true
}
}

resource "aws_dynamodb_table" "notifications" {
  name         = "${var.project_name}-notifications"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "notification_id"
  range_key    = "user_id"

  attribute {
    name = "notification_id"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  tags = { Name = "${var.project_name}-dynamodb-notifications" }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
  tags = { Name = "${var.project_name}-vpc-endpoint-s3" }
}

# VPC Endpoint para DynamoDB — el trafico no sale por internet
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
  tags = { Name = "${var.project_name}-vpc-endpoint-dynamodb" }
}

resource "aws_s3_bucket" "reportes" {
  bucket = "${var.project_name}-reportes-fotos-${var.environment}"
  tags   = { Name = "${var.project_name}-s3-reportes" }
}

resource "aws_s3_bucket_public_access_block" "reportes" {
  bucket                  = aws_s3_bucket.reportes.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "reportes" {
  bucket = aws_s3_bucket.reportes.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "reportes" {
  bucket = aws_s3_bucket.reportes.id
  versioning_configuration {
    status = "Enabled"
  }
}
