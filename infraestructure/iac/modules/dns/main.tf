

# =============================================================================
# modules/dns/main.tf
# Route 53 Hosted Zone para SEGAT
# =============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

resource "aws_route53_zone" "main" {
  name    = var.domain_name
  comment = "Zona DNS principal del proyecto SEGAT"
  tags    = { Name = "${local.name_prefix}-hosted-zone" }
}

