

# =============================================================================
# modules/certificates/main.tf
# Certificado auto-firmado para pruebas (sin dominio real registrado).
# Cuando se tenga un dominio real, reemplazar por validacion DNS con Route53.
# =============================================================================

resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "main" {
  private_key_pem = tls_private_key.main.private_key_pem

  subject {
    common_name  = "${var.project_name}.${var.domain_name}"
    organization = "SEGAT - UPAO"
  }

  validity_period_hours = 8760 # 1 año

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "main" {
  private_key      = tls_private_key.main.private_key_pem
  certificate_body = tls_self_signed_cert.main.cert_pem

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.project_name}-acm-certificate-self-signed" }
}

