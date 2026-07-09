# =============================================================================
# github_oidc.tf — Federacion OIDC para que GitHub Actions pueda autenticarse
# contra AWS sin credenciales de larga duracion (Fase 5: pipeline CI/CD)
#
# IMPORTANTE: este archivo define recursos nuevos que TODAVIA NO se aplicaron
# (no se corrio "terraform apply"). Hasta que se aplique, el job de CI/CD que
# publica la imagen a ECR va a quedar deshabilitado (no existe el secret
# AWS_GHA_ROLE_ARN en GitHub). Ver README para el procedimiento.
# =============================================================================

data "tls_certificate" "github_actions" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_actions.certificates[0].sha1_fingerprint]
  tags            = { Name = "${var.project_name}-oidc-github-actions" }
}

# Rol que solo puede ser asumido por workflows de GitHub Actions corriendo
# sobre la rama main de este repositorio especifico (ni PRs, ni otras ramas,
# ni otros repos).
resource "aws_iam_role" "github_actions_ecr_push" {
  name = "${var.project_name}-gha-ecr-push"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github_actions.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:Angel14Salva/proyecto_final_iac:ref:refs/heads/main"
        }
      }
    }]
  })

  tags = { Name = "${var.project_name}-role-gha-ecr-push" }
}

resource "aws_iam_role_policy" "github_actions_ecr_push" {
  name = "${var.project_name}-gha-ecr-push-policy"
  role = aws_iam_role.github_actions_ecr_push.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EcrAuth"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "EcrPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:BatchGetImage"
        ]
        Resource = aws_ecr_repository.segat_backend.arn
      }
    ]
  })
}

output "github_actions_role_arn" {
  description = "ARN del rol que GitHub Actions asume via OIDC — copiar al secret AWS_GHA_ROLE_ARN del repo"
  value       = aws_iam_role.github_actions_ecr_push.arn
}
