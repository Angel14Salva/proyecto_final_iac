# =============================================================================
# acm.tf — Certificados SSL/TLS
# ACM Certificate para HTTPS en ALB externo e interno
# =============================================================================

resource "aws_acm_certificate" "main" {
  domain_name       = "${var.project_name}.${var.domain_name}"
  validation_method = "DNS"

  subject_alternative_names = [
    "*.${var.project_name}.${var.domain_name}"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.project_name}-acm-certificate" }
}

resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
