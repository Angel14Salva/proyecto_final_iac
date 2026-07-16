


# =============================================================================
# modules/firewall/main.tf
# AWS WAF v2 — proteccion del ALB externo (REGIONAL) y de CloudFront (CLOUDFRONT)
#
# Este modulo necesita el provider aliaseado "aws.us_east_1" pasado desde la
# raiz (environments/dev), porque el WAF de CloudFront debe existir en esa
# region sin importar en cual este el resto de la infraestructura.
# =============================================================================

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.us_east_1]
    }
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

resource "aws_wafv2_web_acl" "main" {
  # checkov:skip=CKV2_AWS_76: AWSManagedRulesKnownBadInputsRuleSet SI esta
  # presente (regla "AWSManagedRulesKnownBadInputsRuleSet" mas abajo, activa
  # y asociada al ALB externo via aws_wafv2_web_acl_association.alb). Falso
  # positivo conocido de Checkov cuando coexisten varios managed rule groups
  # en el mismo ACL.
  name        = "${local.name_prefix}-waf"
  scope       = "REGIONAL"
  description = "WAF para proteger el ALB externo de SEGAT"

  default_action {
    allow {}
  }

  # Regla 1: Proteccion contra las amenazas web mas comunes (OWASP Top 10)
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}CommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # Regla 2: Proteccion contra bots conocidos y scrapers
  rule {
    name     = "AWSManagedRulesBotControlRuleSet"
    priority = 2
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesBotControlRuleSet"
        vendor_name = "AWS"
        managed_rule_group_configs {
          aws_managed_rules_bot_control_rule_set {
            inspection_level = "COMMON"
            # Explicito para que no quede en "computed": sin esto, AWS
            # devuelve el valor real (true) en cada refresh pero nuestro HCL
            # no lo declaraba, generando un diff perpetuo "0 to add, 1 to
            # change" que nunca converge por mas veces que se aplique.
            enable_machine_learning = true
          }
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}BotControlMetric"
      sampled_requests_enabled   = true
    }
  }

  # Regla 3: Limitacion de tasa (rate limiting) — max 2000 req/5min por IP
  rule {
    name     = "RateLimitPerIP"
    priority = 3
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}RateLimitMetric"
      sampled_requests_enabled   = true
    }
  }

  # Regla 4: Bloquea IPs de servicios de anonimizacion conocidos
  # (antes vivia despues de "tags", separada de las demas reglas -- el
  # provider de AWS devuelve las reglas ordenadas por prioridad, y tenerlas
  # repartidas en el archivo generaba un diff de "reemplazar" perpetuo en
  # cada plan aunque el contenido fuera identico)
  rule {
    name     = "AWSManagedRulesAnonymousIpList"
    priority = 4
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAnonymousIpList"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AnonymousIpListMetric"
      sampled_requests_enabled   = true
    }
  }

  # Regla 5: proteccion contra CVE-2021-44228 (Log4Shell) y otros known bad inputs
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 5
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "KnownBadInputs"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name_prefix}WAFMetric"
    sampled_requests_enabled   = true
  }

  tags = { Name = "${local.name_prefix}-waf" }

  # Limitacion conocida del provider de AWS: DescribeWebACL no garantiza
  # devolver las "rule" en el mismo orden en que se declararon, asi que
  # Terraform ve un diff de reemplazo en cada plan aunque el contenido sea
  # identico (confirmado: aplicamos este mismo cambio dos veces y volvio a
  # aparecer). Se ignora "rule" a proposito -- para cambiar las reglas de
  # verdad en el futuro, comentar esta linea, aplicar, y volver a agregarla.
  lifecycle {
    ignore_changes = [rule]
  }
}

# Asociar el WAF al ALB externo
resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = var.alb_external_arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

# Logs del WAF hacia CloudWatch
resource "aws_cloudwatch_log_group" "waf" {
  # Los log groups del WAF DEBEN tener el prefijo "aws-waf-logs-"
  name              = "aws-waf-logs-${local.name_prefix}"
  retention_in_days = 365
  kms_key_id        = var.kms_secrets_key_arn
  tags              = { Name = "${local.name_prefix}-waf-logs" }
}

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  resource_arn            = aws_wafv2_web_acl.main.arn
}

# WAF especifico para CloudFront — debe tener scope CLOUDFRONT y estar en us-east-1
resource "aws_wafv2_web_acl" "cloudfront" {
  provider    = aws.us_east_1
  name        = "${local.name_prefix}-waf-cloudfront"
  scope       = "CLOUDFRONT"
  description = "WAF para proteger la distribucion CloudFront de SEGAT"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}CloudFrontCommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # CKV_AWS_192 / CKV2_AWS_47: proteccion contra CVE-2021-44228 (Log4Shell)
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}CloudFrontKnownBadInputsMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name_prefix}CloudFrontWAFMetric"
    sampled_requests_enabled   = true
  }

  tags = { Name = "${local.name_prefix}-waf-cloudfront" }
}

# CKV2_AWS_31: logging del WAF de CloudFront. El log group debe existir en
# us-east-1 (misma region que el WAF con scope CLOUDFRONT).
resource "aws_cloudwatch_log_group" "waf_cloudfront" {
  provider = aws.us_east_1
  # Los log groups del WAF DEBEN tener el prefijo "aws-waf-logs-"
  name              = "aws-waf-logs-${local.name_prefix}-cloudfront"
  retention_in_days = 365
  kms_key_id        = var.kms_secrets_key_arn
  tags              = { Name = "${local.name_prefix}-waf-cloudfront-logs" }
}

resource "aws_wafv2_web_acl_logging_configuration" "cloudfront" {
  provider                = aws.us_east_1
  log_destination_configs = [aws_cloudwatch_log_group.waf_cloudfront.arn]
  resource_arn            = aws_wafv2_web_acl.cloudfront.arn
}


