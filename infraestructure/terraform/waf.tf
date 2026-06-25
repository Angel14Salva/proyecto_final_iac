# =============================================================================
# waf.tf — AWS WAF v2
# Proteccion del ALB externo segun el diagrama de arquitectura
# =============================================================================

resource "aws_wafv2_web_acl" "main" {
  name  = "${var.project_name}-waf"
  scope = "REGIONAL"
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
      metric_name                = "${var.project_name}CommonRuleSetMetric"
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
          }
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}BotControlMetric"
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
      metric_name                = "${var.project_name}RateLimitMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}WAFMetric"
    sampled_requests_enabled   = true
  }

  tags = { Name = "${var.project_name}-waf" }
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 3
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
}

# Asociar el WAF al ALB externo
resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.external.arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

# Logs del WAF hacia CloudWatch
resource "aws_cloudwatch_log_group" "waf" {
  # Los log groups del WAF DEBEN tener el prefijo "aws-waf-logs-"
  name              = "aws-waf-logs-${var.project_name}"
  retention_in_days = 90
  tags              = { Name = "${var.project_name}-waf-logs" }
}

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  resource_arn            = aws_wafv2_web_acl.main.arn
}
