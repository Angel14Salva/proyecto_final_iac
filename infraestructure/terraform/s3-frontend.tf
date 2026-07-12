
# =============================================================================
# s3-frontend.tf — Bucket S3 privado para los assets estaticos del frontend
# (apps/frontend). Se sirve exclusivamente a traves de la distribucion
# CloudFront principal (cloudfront.tf) mediante Origin Access Control (OAC);
# el bucket nunca es publico.
# =============================================================================

resource "aws_s3_bucket" "frontend" {
  bucket = "${var.project_name}-frontend-${var.environment}-${data.aws_caller_identity.current.account_id}"
  tags   = { Name = "${var.project_name}-s3-frontend" }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = "alias/aws/s3"
    }
  }
}

resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_logging" "frontend" {
  bucket        = aws_s3_bucket.frontend.id
  target_bucket = aws_s3_bucket.alb_logs.id
  target_prefix = "s3-frontend-access-logs/"
}

resource "aws_s3_bucket_lifecycle_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  rule {
    id     = "expire-old-versions"
    status = "Enabled"
    noncurrent_version_expiration { noncurrent_days = 30 }
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }
}

resource "aws_s3_bucket_notification" "frontend" {
  bucket      = aws_s3_bucket.frontend.id
  eventbridge = true
}

# Mismo patron condicional que reportes/alb_logs/cloudtrail_logs (data.tf,
# ecs.tf, observability.tf): la replicacion solo se activa si el bucket
# destino (replication_bucket_frontend) ya existe.
resource "aws_s3_bucket_replication_configuration" "frontend" {
  count      = var.enable_s3_replication ? 1 : 0
  depends_on = [aws_s3_bucket_versioning.frontend]
  role       = aws_iam_role.s3_replication.arn
  bucket     = aws_s3_bucket.frontend.id
  rule {
    id     = "replicacion-frontend"
    status = "Enabled"
    destination {
      bucket        = "arn:aws:s3:::${var.replication_bucket_frontend}"
      storage_class = "STANDARD"
    }
  }
}

# ---------------------------------------------------------------------------
# Origin Access Control — permite que SOLO la distribucion CloudFront
# principal pueda leer objetos de este bucket (reemplazo moderno de OAI)
# ---------------------------------------------------------------------------
resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${var.project_name}-frontend-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

data "aws_iam_policy_document" "frontend_bucket_policy" {
  statement {
    sid       = "AllowCloudFrontOAC"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.frontend.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.main.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.frontend_bucket_policy.json
}

