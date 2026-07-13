
# =============================================================================
# modules/oidc/main.tf
# Federacion OIDC para que GitHub Actions se autentique contra AWS sin
# credenciales de larga duracion.
# =============================================================================

data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  # El provider OIDC es unico por cuenta AWS (ver variables.tf). Si este
  # entorno no lo administra, su ARN sigue siendo predecible -- no hace falta
  # leerlo del state de otro entorno.
  oidc_provider_arn = var.manage_oidc_provider ? aws_iam_openid_connect_provider.github_actions[0].arn : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
}

data "tls_certificate" "github_actions" {
  count = var.manage_oidc_provider ? 1 : 0
  url   = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  count           = var.manage_oidc_provider ? 1 : 0
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_actions[0].certificates[0].sha1_fingerprint]
  tags            = { Name = "${local.name_prefix}-oidc-github-actions" }
}

# Rol que solo puede ser asumido por workflows de GitHub Actions corriendo
# sobre la rama main de este repositorio especifico (ni PRs, ni otras ramas,
# ni otros repos).
resource "aws_iam_role" "github_actions_ecr_push" {
  name = "${local.name_prefix}-gha-ecr-push"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:ref:refs/heads/main"
        }
      }
    }]
  })

  tags = { Name = "${local.name_prefix}-role-gha-ecr-push" }
}

resource "aws_iam_role_policy" "github_actions_ecr_push" {
  name = "${local.name_prefix}-gha-ecr-push-policy"
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
        Resource = var.ecr_repository_arn
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# Rol separado para el deploy del frontend (sync a S3 + invalidacion de
# CloudFront). Se mantiene aparte del rol de ECR para no darle al pipeline
# del frontend permisos sobre el registro de imagenes del backend.
# ---------------------------------------------------------------------------
resource "aws_iam_role" "github_actions_frontend_deploy" {
  name = "${local.name_prefix}-gha-frontend-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:ref:refs/heads/main"
        }
      }
    }]
  })

  tags = { Name = "${local.name_prefix}-role-gha-frontend-deploy" }
}

resource "aws_iam_role_policy" "github_actions_frontend_deploy" {
  name = "${local.name_prefix}-gha-frontend-deploy-policy"
  role = aws_iam_role.github_actions_frontend_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3SyncFrontend"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          var.s3_frontend_bucket_arn,
          "${var.s3_frontend_bucket_arn}/*"
        ]
      },
      {
        Sid      = "CloudFrontInvalidation"
        Effect   = "Allow"
        Action   = ["cloudfront:CreateInvalidation"]
        Resource = var.cloudfront_distribution_arn
      }
    ]
  })
}
