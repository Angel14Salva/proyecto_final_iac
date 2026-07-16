

# =============================================================================
# modules/cdn/main.tf
# CloudFront + S3 (assets estaticos del frontend)
#
# Fusiona los antiguos cloudfront.tf y s3-frontend.tf en un solo modulo: se
# referenciaban mutuamente (el bucket necesita el ARN de la distribucion para
# su policy vía OAC, la distribucion necesita el bucket como origen), asi que
# no se pueden separar en dos modulos sin crear una dependencia circular.
# =============================================================================

data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ---------------------------------------------------------------------------
# S3 — assets estaticos del frontend (apps/frontend)
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "frontend" {
  bucket = "${local.name_prefix}-frontend-${data.aws_caller_identity.current.account_id}"
  tags   = { Name = "${local.name_prefix}-s3-frontend" }
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
      sse_algorithm = "AES256"
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
  target_bucket = var.alb_logs_bucket_id
  target_prefix = "s3-frontend-access-logs/"
}

resource "aws_s3_bucket_lifecycle_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  rule {
    id     = "expire-old-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration { noncurrent_days = 30 }
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }
}

resource "aws_s3_bucket_notification" "frontend" {
  bucket      = aws_s3_bucket.frontend.id
  eventbridge = true
}

# Mismo patron condicional que reportes/alb_logs/cloudtrail_logs: la
# replicacion solo se activa si el bucket destino ya existe.
resource "aws_s3_bucket_replication_configuration" "frontend" {
  count      = var.enable_s3_replication ? 1 : 0
  depends_on = [aws_s3_bucket_versioning.frontend]
  role       = var.s3_replication_role_arn
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
  name                              = "${local.name_prefix}-frontend-oac"
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

# ---------------------------------------------------------------------------
# CloudFront
# ---------------------------------------------------------------------------
resource "aws_cloudfront_response_headers_policy" "segat" {
  name    = "${local.name_prefix}-response-headers-policy"
  comment = "Headers de seguridad para SEGAT"

  security_headers_config {
    content_type_options {
      override = true
    }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }
    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }
  }
}

resource "aws_cloudfront_distribution" "main" {
  # checkov:skip=CKV2_AWS_46: Los origenes ALB son custom origins, no S3; el
  # unico origen S3 (frontend) SI usa Origin Access Control (ver origin de abajo).
  # checkov:skip=CKV2_AWS_47: AWSManagedRulesKnownBadInputsRuleSet SI esta
  # presente en el WAF asociado (modules.firewall), activa y con web_acl_id
  # apuntando a ese ACL mas abajo. Mismo falso positivo que CKV2_AWS_76.
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CDN para el proyecto SEGAT"
  default_root_object = "index.html"

  # Origen S3 — assets estaticos del frontend, privado, accesible solo por
  # esta distribucion via Origin Access Control.
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "${local.name_prefix}-frontend-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  origin {
    domain_name = var.alb_external_dns_name
    origin_id   = "${local.name_prefix}-alb-origin"

    # http-only: el ALB presenta un certificado autofirmado (no hay dominio
    # real registrado para pedir uno valido via ACM) y CloudFront rechaza
    # certificados no confiables en origenes custom sin excepcion posible.
    # Este tramo es trafico interno de AWS (CloudFront -> ALB), no expuesto a
    # internet; el cliente real sigue viendo HTTPS de punta a punta via
    # CloudFront. El listener :80 del ALB reenvia directo (no redirige).
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  origin {
    domain_name = var.alb_internal_dns_name
    origin_id   = "${local.name_prefix}-alb-internal-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  origin_group {
    origin_id = "${local.name_prefix}-origin-group"
    failover_criteria {
      status_codes = [500, 502, 503, 504]
    }
    member {
      origin_id = "${local.name_prefix}-alb-origin"
    }
    member {
      origin_id = "${local.name_prefix}-alb-internal-origin"
    }
  }

  # Comportamiento por defecto: sirve el frontend estatico (SPA) desde S3.
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "${local.name_prefix}-frontend-origin"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl                    = 0
    default_ttl                = 3600
    max_ttl                    = 86400
    response_headers_policy_id = aws_cloudfront_response_headers_policy.segat.id
  }

  # /api/* — proxy hacia el backend (ALB externo, origen unico).
  ordered_cache_behavior {
    path_pattern = "/api/*"
    # CloudFront no permite metodos de escritura (POST/PUT/PATCH/DELETE) en un
    # cache behavior que apunta a un origin_group (failover) -- "InvalidArgument:
    # AllowedMethods cannot include POST, PUT, PATCH, or DELETE for a cached
    # behavior associated with an origin group". Por eso apunta a un origen
    # unico (el ALB externo) en vez del origin_group: se pierde el failover
    # automatico al ALB interno para esta ruta, pero el login y cualquier
    # escritura de la API dejan de estar bloqueados.
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "${local.name_prefix}-alb-origin"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    # User-Agent debe reenviarse: sin el, el origen (y su WAF) siempre ve
    # "Amazon CloudFront" como User-Agent en vez del cliente real, y el WAF
    # Bot Control bloquea esas peticiones por "User-Agent no-browser" -- eso
    # bloqueaba a CUALQUIER cliente que pasara por esta ruta, no solo bots.
    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Host", "User-Agent"]
      cookies {
        forward = "all"
      }
    }

    min_ttl                    = 0
    default_ttl                = 0
    max_ttl                    = 0
    response_headers_policy_id = aws_cloudfront_response_headers_policy.segat.id
  }

  # SPA: rutas del frontend manejadas por JS del lado cliente (sin servidor
  # de rutas). Si S3 devuelve 403/404 para una ruta como /reportes, se
  # reenvia a index.html para que el router del frontend la resuelva.
  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["PE", "US", "CO", "MX", "AR", "CL", "EC", "BO"]
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  web_acl_id = var.waf_cloudfront_arn

  logging_config {
    include_cookies = false
    bucket          = var.alb_logs_bucket_domain_name
    prefix          = "cloudfront/"
  }

  tags = { Name = "${local.name_prefix}-cloudfront" }
}

