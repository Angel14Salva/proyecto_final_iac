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
  # checkov:skip=CKV2_AWS_46: El origin es un ALB, no un bucket S3. Origin Access Control aplica solo para origenes S3.
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CDN para el proyecto SEGAT"
  default_root_object = "index.html"

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

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "${var.project_name}-origin-group"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

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

  web_acl_id = aws_wafv2_web_acl.main.arn

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.alb_logs.bucket_domain_name
    prefix          = "cloudfront/"
  }

  tags = { Name = "${var.project_name}-cloudfront" }
}
