

# =============================================================================
# modules/dns/main.tf
# Route 53 Hosted Zone para SEGAT
# =============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

resource "aws_route53_zone" "main" {
  # checkov:skip=CKV2_AWS_38: DNSSEC no aplica -- esta hosted zone no esta
  # delegada desde un registrador real (no hay dominio real registrado, ver
  # modules.certificates), asi que no hay cadena de confianza DNS padre que
  # firmar. Activar DNSSEC sin delegacion real no aporta nada.
  # checkov:skip=CKV2_AWS_39: Mismo motivo -- la zona no resuelve trafico DNS
  # real (sin delegacion desde un registrador), asi que no hay consultas que
  # loguear.
  name    = var.domain_name
  comment = "Zona DNS principal del proyecto SEGAT"
  tags    = { Name = "${local.name_prefix}-hosted-zone" }
}

