
# =============================================================================
# modules/oidc/main.tf
# Federacion OIDC para que GitHub Actions se autentique contra AWS sin
# credenciales de larga duracion.
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
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:ref:refs/heads/main"
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
  name = "${var.project_name}-gha-frontend-deploy"

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
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:ref:refs/heads/main"
        }
      }
    }]
  })

  tags = { Name = "${var.project_name}-role-gha-frontend-deploy" }
}

resource "aws_iam_role_policy" "github_actions_frontend_deploy" {
  name = "${var.project_name}-gha-frontend-deploy-policy"
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
