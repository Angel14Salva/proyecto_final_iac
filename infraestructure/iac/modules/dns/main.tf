

# =============================================================================
# modules/dns/main.tf
# Route 53 Hosted Zone para SEGAT
# =============================================================================

resource "aws_route53_zone" "main" {
  name    = var.domain_name
  comment = "Zona DNS principal del proyecto SEGAT"
  tags    = { Name = "${var.project_name}-hosted-zone" }
}

