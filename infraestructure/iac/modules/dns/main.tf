
# =============================================================================
# modules/dns/main.tf
# Route 53 Hosted Zone y registros DNS para SEGAT
# =============================================================================

resource "aws_route53_zone" "main" {
  name    = var.domain_name
  comment = "Zona DNS principal del proyecto SEGAT"
  tags    = { Name = "${var.project_name}-hosted-zone" }
}

resource "aws_route53_record" "alb_external" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "${var.project_name}.${var.domain_name}"
  type    = "A"
  alias {
    name                   = var.alb_external_dns_name
    zone_id                = var.alb_external_zone_id
    evaluate_target_health = true
  }
}
