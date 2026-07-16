

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

  # Mapeo de entorno -> rama que puede asumir el rol de este entorno. Debe
  # coincidir con la resolucion de entorno en .github/workflows/backend-cd.yml
  # (feature->dev, develop->qa, main->prod) -- sin esto, el trust policy
  # solo permitia "main"/"feature" en los 3 entornos, y el deploy a qa
  # (que corre desde "develop") fallaba con AccessDenied en AssumeRoleWithWebIdentity.
  branch_by_environment = {
    dev  = "feature"
    qa   = "develop"
    prod = "main"
  }
  trusted_branch = lookup(local.branch_by_environment, var.environment, var.environment)
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
# en el job de cd.yml que corresponde a este entorno. GitHub cambia el
# formato del claim "sub" del token OIDC cuando el job que lo genera declara
# "environment: <nombre>" (como hace backend-deploy en cd.yml, para poder
# leer las variables/secrets del GitHub Environment correcto): en vez de
# "repo:<owner>/<repo>:ref:refs/heads/<rama>" el token trae
# "repo:<owner>/<repo>:environment:<nombre>". Antes este trust policy solo
# aceptaba el formato por rama, y por eso el AssumeRoleWithWebIdentity
# fallaba con "Not authorized" aunque el rol y el proveedor OIDC existieran
# bien -- el token real nunca calzaba con la condicion.
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
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:environment:${var.environment}"
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
      },
      {
        Sid      = "EcsForceDeploy"
        Effect   = "Allow"
        Action   = ["ecs:UpdateService", "ecs:DescribeServices"]
        Resource = var.ecs_service_arn
      },
      {
        # RegisterTaskDefinition/DescribeTaskDefinition no soportan permisos
        # a nivel de recurso (la ARN de una revision nueva no existe todavia
        # al momento de autorizar la llamada) -- AWS exige Resource = "*"
        # para estas dos acciones.
        Sid      = "EcsRegisterTaskDefinition"
        Effect   = "Allow"
        Action   = ["ecs:RegisterTaskDefinition", "ecs:DescribeTaskDefinition"]
        Resource = "*"
      },
      {
        # Registrar una task definition exige poder "pasar" los roles de
        # ejecucion/tarea que va a usar ECS -- sin esto, RegisterTaskDefinition
        # falla con AccessDenied aunque el Sid de arriba lo permita.
        Sid    = "PassRoleForEcsTasks"
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = [
          var.ecs_execution_role_arn,
          var.ecs_task_role_arn,
        ]
        Condition = {
          StringEquals = { "iam:PassedToService" = "ecs-tasks.amazonaws.com" }
        }
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
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:ref:refs/heads/${local.trusted_branch}"
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

# ---------------------------------------------------------------------------
# Rol para el pipeline de "Terraform CD" (plan + apply automatico de
# infraestructure/iac/environments/<env>). Necesita permisos mucho mas
# amplios que los roles de arriba porque crea/modifica la infraestructura
# real (VPC, RDS, ECS, Cognito, WAF, etc.), no solo hace deploy de la app
# sobre infraestructura ya existente.
# ---------------------------------------------------------------------------
# Igual que github_actions_ecr_push arriba: usa el claim "sub" con formato
# "environment:" porque terraform-apply (en cd.yml) tambien corre dentro de
# un job con "environment: <nombre>" declarado.
resource "aws_iam_role" "github_actions_terraform_apply" {
  name = "${local.name_prefix}-gha-terraform-apply"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:environment:${var.environment}"
        }
      }
    }]
  })

  tags = { Name = "${local.name_prefix}-role-gha-terraform-apply" }
}

# PowerUserAccess cubre casi todos los servicios que estos modulos usan
# (VPC, ECS, RDS, ElastiCache, DynamoDB, S3, CloudFront, Route53, ACM,
# Cognito, API Gateway, WAFv2, KMS, SNS, SQS, Secrets Manager, CloudTrail,
# Config) pero excluye a proposito la administracion de IAM -- eso se cubre
# aparte con la policy de abajo, acotada solo a los recursos de este entorno.
resource "aws_iam_role_policy_attachment" "terraform_apply_power_user" {
  role       = aws_iam_role.github_actions_terraform_apply.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# PowerUserAccess deliberadamente no incluye IAM. Los 14 modulos SI crean
# roles/policies (modules.security, modules.oidc, etc.), asi que el pipeline
# necesita permisos de IAM -- acotados por Resource a los roles/policies con
# el prefijo de ESTE entorno (${local.name_prefix}-*), no a cualquier IAM de
# la cuenta.
resource "aws_iam_role_policy" "terraform_apply_iam" {
  # checkov:skip=CKV_AWS_289: Este rol EXISTE para administrar IAM -- los 14
  # modulos de infraestructure/iac crean roles/policies (modules.security,
  # este mismo modulo, etc.), asi que el pipeline de Terraform CD no puede
  # funcionar sin poder crear/modificar roles. El riesgo de escalada esta
  # acotado por Resource a "${local.name_prefix}-*" (solo los roles propios
  # de ESTE entorno, no cualquier IAM de la cuenta) y por el trust policy de
  # este mismo rol (solo lo asume el workflow de GitHub Actions corriendo en
  # local.trusted_branch, ver arriba).
  # checkov:skip=CKV_AWS_355: El unico Sid con Resource = "*" es
  # "CreateServiceLinkedRoles" -- iam:CreateServiceLinkedRole es una accion
  # que AWS exige autorizar con Resource = "*" (el ARN del service-linked
  # role no existe todavia al momento de autorizar la llamada), documentado
  # asi por AWS para ECS/RDS/Elasticache/Config y otros servicios usados
  # aqui.
  name = "${local.name_prefix}-gha-terraform-apply-iam"
  role = aws_iam_role.github_actions_terraform_apply.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ManageOwnEnvironmentRoles"
        Effect = "Allow"
        Action = [
          "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:UpdateRole",
          "iam:UpdateAssumeRolePolicy", "iam:TagRole", "iam:UntagRole",
          "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy",
          "iam:ListRolePolicies", "iam:ListAttachedRolePolicies",
          "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:PassRole",
        ]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.name_prefix}-*",
        ]
      },
      {
        # El provider OIDC (aws_iam_openid_connect_provider) solo lo
        # administra el entorno con manage_oidc_provider=true -- este
        # Sid solo importa en ese entorno; en los demas la policy se crea
        # igual (misma policy en los 3 entornos) pero nunca se usa.
        Sid    = "ManageOidcProvider"
        Effect = "Allow"
        Action = [
          "iam:CreateOpenIDConnectProvider", "iam:DeleteOpenIDConnectProvider",
          "iam:GetOpenIDConnectProvider", "iam:UpdateOpenIDConnectProviderThumbprint",
          "iam:TagOpenIDConnectProvider", "iam:UntagOpenIDConnectProvider",
          "iam:AddClientIDToOpenIDConnectProvider",
        ]
        Resource = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"]
      },
      {
        # Varios servicios administrados (ECS, RDS, Elasticache, Config,
        # etc.) crean su propio service-linked role la primera vez que se
        # usan -- AWS exige Resource = "*" para esta accion especifica,
        # el ARN del rol no se puede acotar de antemano.
        Sid      = "CreateServiceLinkedRoles"
        Effect   = "Allow"
        Action   = "iam:CreateServiceLinkedRole"
        Resource = "*"
      },
    ]
  })
}

