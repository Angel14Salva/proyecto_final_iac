
# =============================================================================
# cloudfront.tf — CDN
# Amazon CloudFront para distribucion de contenido estatico SEGAT
# =============================================================================

resource "aws_cloudfront_response_headers_policy" "segat" {
  name    = "${var.project_name}-response-headers-policy"
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
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CDN para el proyecto SEGAT"
  default_root_object = "index.html"

  # Origen S3 — assets estaticos del frontend (apps/frontend), privado,
  # accesible solo por esta distribucion via Origin Access Control.
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "${var.project_name}-frontend-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  origin {
    domain_name = aws_lb.external.dns_name
    origin_id   = "${var.project_name}-alb-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  origin {
    domain_name = aws_lb.internal.dns_name
    origin_id   = "${var.project_name}-alb-internal-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  origin_group {
    origin_id = "${var.project_name}-origin-group"
    failover_criteria {
      status_codes = [500, 502, 503, 504]
    }
    member {
      origin_id = "${var.project_name}-alb-origin"
    }
    member {
      origin_id = "${var.project_name}-alb-internal-origin"
    }
  }

  # Comportamiento por defecto: sirve el frontend estatico (SPA) desde S3.
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "${var.project_name}-frontend-origin"
    viewer_protocol_policy = "redirect-to-https"
    compress                = true

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

  # /api/* — proxy hacia el backend (ALB con failover), igual que antes.
  ordered_cache_behavior {
    path_pattern = "/api/*"
    # CloudFront no permite metodos de escritura (POST/PUT/PATCH/DELETE) en un
    # cache behavior que apunta a un origin_group (failover) -- "InvalidArgument:
    # AllowedMethods cannot include POST, PUT, PATCH, or DELETE for a cached
    # behavior associated with an origin group". Se mantiene el failover; las
    # escrituras deben ir directo al ALB o via API Gateway, no por esta URL.
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "${var.project_name}-origin-group"
    viewer_protocol_policy = "redirect-to-https"
    compress                = true

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Host"]
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
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }
  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["PE", "US", "CO", "MX", "AR", "CL", "EC", "BO"]
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.main.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  web_acl_id = aws_wafv2_web_acl.cloudfront.arn

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.alb_logs.bucket_domain_name
    prefix          = "cloudfront/"
  }

  tags = { Name = "${var.project_name}-cloudfront" }
}

