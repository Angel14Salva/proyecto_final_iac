# =============================================================================
# data.tf — FASE 4: Capa de datos
# RDS PostgreSQL + ElastiCache Redis + DynamoDB + S3
# =============================================================================

resource "aws_db_parameter_group" "postgresql" {
  name   = "${var.project_name}-pg-params"
  family = "postgres15"
  parameter {
    name  = "log_statement"
    value = "all"
  }
  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }
  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }
  tags = { Name = "${var.project_name}-pg-params" }
}

resource "aws_db_subnet_group" "rds" {
  name       = "${var.project_name}-rds-subnet-group"
  subnet_ids = [aws_subnet.private_c.id, aws_subnet.private_c2.id]
  tags       = { Name = "${var.project_name}-rds-subnet-group" }
}

resource "aws_db_instance" "postgresql" {
  identifier                          = "${var.project_name}-postgresql"
  engine                              = "postgres"
  engine_version                      = "15.7"
  instance_class                      = "db.t3.micro"
  allocated_storage                   = 20
  storage_type                        = "gp2"
  storage_encrypted                   = true
  db_name                             = var.db_name
  username                            = var.db_username
  password                            = var.db_password
  db_subnet_group_name                = aws_db_subnet_group.rds.name
  parameter_group_name                = aws_db_parameter_group.postgresql.name
  vpc_security_group_ids              = [aws_security_group.rds.id]
  backup_retention_period             = 1
  skip_final_snapshot                 = true
  deletion_protection                 = true
  multi_az                            = true
  copy_tags_to_snapshot               = true
  iam_database_authentication_enabled = true
  performance_insights_enabled        = true
  performance_insights_kms_key_id     = data.aws_kms_key.rds.arn
  enabled_cloudwatch_logs_exports     = ["postgresql", "upgrade"]
  auto_minor_version_upgrade          = true
  monitoring_interval                 = 60
  monitoring_role_arn                 = aws_iam_role.rds_monitoring.arn
  tags                                = { Name = "${var.project_name}-postgresql" }
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.project_name}-redis-subnet-group"
  subnet_ids = [aws_subnet.private_c.id, aws_subnet.private_c2.id]
  tags       = { Name = "${var.project_name}-redis-subnet-group" }
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id               = "${var.project_name}-redis"
  engine                   = "redis"
  node_type                = "cache.t3.micro"
  num_cache_nodes          = 1
  parameter_group_name     = "default.redis7"
  engine_version           = "7.0"
  port                     = 6379
  subnet_group_name        = aws_elasticache_subnet_group.redis.name
  security_group_ids       = [aws_security_group.redis.id]
  snapshot_retention_limit = 1
  tags                     = { Name = "${var.project_name}-redis-cache" }
}

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

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb.arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = { Name = "${var.project_name}-dynamodb-gps" }
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

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb.arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = { Name = "${var.project_name}-dynamodb-notifications" }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
  tags              = { Name = "${var.project_name}-vpc-endpoint-s3" }
}

resource "aws_s3_bucket" "reportes" {
  bucket = "${var.project_name}-reportes-fotos-${var.environment}"
  tags   = { Name = "${var.project_name}-s3-reportes" }
}

resource "aws_s3_bucket_replication_configuration" "reportes" {
  depends_on = [aws_s3_bucket_versioning.reportes]
  role       = aws_iam_role.s3_replication.arn
  bucket     = aws_s3_bucket.reportes.id
  rule {
    id     = "replicacion-reportes"
    status = "Enabled"
    destination {
      bucket        = "arn:aws:s3:::${var.replication_bucket_reportes}"
      storage_class = "STANDARD"
    }
  }
}

resource "aws_s3_bucket_notification" "reportes" {
  bucket      = aws_s3_bucket.reportes.id
  eventbridge = true
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
      sse_algorithm     = "aws:kms"
      kms_master_key_id = "alias/aws/s3"
    }
  }
}

resource "aws_s3_bucket_versioning" "reportes" {
  bucket = aws_s3_bucket.reportes.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_logging" "reportes" {
  bucket        = aws_s3_bucket.reportes.id
  target_bucket = aws_s3_bucket.reportes.id
  target_prefix = "access-logs/"
}

resource "aws_s3_bucket_lifecycle_configuration" "reportes" {
  bucket = aws_s3_bucket.reportes.id
  rule {
    id     = "expire-old-reports"
    status = "Enabled"
    expiration { days = 365 }
    noncurrent_version_expiration { noncurrent_days = 90 }
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }
}





data "aws_kms_key" "rds" {
  key_id = "alias/aws/rds"
}

resource "aws_kms_key" "dynamodb" {
  # CKV2_AWS_64: policy explicita requerida por Checkov para KMS keys
  description             = "KMS CMK para cifrado de tablas DynamoDB del proyecto SEGAT"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.dynamodb_kms_policy.json
  tags                    = { Name = "${var.project_name}-kms-dynamodb" }
}

data "aws_iam_policy_document" "dynamodb_kms_policy" {
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
  tags              = { Name = "${var.project_name}-vpc-endpoint-dynamodb" }
}

resource "aws_kms_alias" "dynamodb" {
  name          = "alias/${var.project_name}/dynamodb"
  target_key_id = aws_kms_key.dynamodb.key_id
}
