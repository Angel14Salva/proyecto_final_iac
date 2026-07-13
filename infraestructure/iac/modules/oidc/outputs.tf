
output "github_actions_role_arn" {
  description = "ARN del rol que GitHub Actions asume via OIDC — copiar al secret AWS_GHA_ROLE_ARN del repo"
  value       = aws_iam_role.github_actions_ecr_push.arn
}

output "github_actions_frontend_role_arn" {
  description = "ARN del rol que GitHub Actions asume via OIDC para desplegar el frontend — copiar al secret/var AWS_GHA_FRONTEND_ROLE_ARN del repo"
  value       = aws_iam_role.github_actions_frontend_deploy.arn
}
