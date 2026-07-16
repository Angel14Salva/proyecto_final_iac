# =============================================================================
# modules/monitoring/outputs.tf
# =============================================================================

output "ecr_prometheus_url" {
  value = aws_ecr_repository.prometheus.repository_url
}

output "ecr_loki_url" {
  value = aws_ecr_repository.loki.repository_url
}

output "ecr_grafana_url" {
  value = aws_ecr_repository.grafana.repository_url
}
