
# =============================================================================
# apigateway.tf — API Gateway
# Amazon API Gateway como punto de entrada para el backend SEGAT
# =============================================================================

resource "aws_api_gateway_rest_api" "segat" {
  name        = "${var.project_name}-api"
  description = "API Gateway para el proyecto SEGAT"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.project_name}-api-gateway" }
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.segat.id
  parent_id   = aws_api_gateway_rest_api.segat.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
  # checkov:skip=CKV2_AWS_53: Es un proxy {proxy+} pass-through hacia el
  # backend -- no hay un JSON schema fijo que validar aqui, el backend hace
  # su propia validacion de payload.
  rest_api_id   = aws_api_gateway_rest_api.segat.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_authorizer" "cognito" {
  name            = "${var.project_name}-cognito-authorizer"
  rest_api_id     = aws_api_gateway_rest_api.segat.id
  type            = "COGNITO_USER_POOLS"
  provider_arns   = [aws_cognito_user_pool.segat.arn]
  identity_source = "method.request.header.Authorization"
}

resource "aws_api_gateway_integration" "proxy" {
  rest_api_id             = aws_api_gateway_rest_api.segat.id
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = aws_api_gateway_method.proxy.http_method
  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  # El ALB interno es privado (subredes privadas, internal=true) y no es
  # alcanzable directamente desde API Gateway. Se llega a el via VPC Link
  # (vpc-link.tf) -> NLB -> ALB interno. El uri debe apuntar al DNS del NLB,
  # no al del ALB.
  uri             = "https://${aws_lb.internal_nlb.dns_name}/{proxy}"
  connection_type = "VPC_LINK"
  connection_id   = aws_api_gateway_vpc_link.internal.id
}

resource "aws_api_gateway_deployment" "segat" {
  rest_api_id = aws_api_gateway_rest_api.segat.id
  depends_on  = [aws_api_gateway_integration.proxy]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod" {
  # checkov:skip=CKV_AWS_120: El cache cluster de API Gateway cobra 24/7
  # independiente del trafico; no se justifica el costo fijo para este
  # proyecto academico. Se puede activar mas adelante si el trafico lo pide.
  # checkov:skip=CKV2_AWS_51: La autenticacion ya la resuelve Cognito
  # (COGNITO_USER_POOLS en el authorizer); exigir ademas certificado de
  # cliente (mTLS) es redundante para este caso de uso.
  deployment_id = aws_api_gateway_deployment.segat.id
  rest_api_id   = aws_api_gateway_rest_api.segat.id
  stage_name    = var.environment

  # access_log_settings tambien exige el rol de CloudWatch a nivel de cuenta
  # (aws_api_gateway_account.main mas abajo), igual que method_settings.proxy.
  depends_on = [aws_api_gateway_account.main]

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.ecs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  xray_tracing_enabled = true

  tags = { Name = "${var.project_name}-api-stage" }
}

# Habilitar logging_level en un stage exige que la cuenta AWS (a nivel de
# region, no por API) tenga configurado un rol de CloudWatch Logs -- sin esto
# UpdateStage falla con "CloudWatch Logs role ARN must be set in account
# settings to enable logging", aunque el stage/metodo este bien configurado.
resource "aws_iam_role" "api_gateway_cloudwatch" {
  name = "${var.project_name}-apigw-cloudwatch-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "apigateway.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  role       = aws_iam_role.api_gateway_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn
}

resource "aws_api_gateway_method_settings" "proxy" {
  # checkov:skip=CKV_AWS_225: Ver skip de CKV_AWS_120 en aws_api_gateway_stage.prod
  # -- misma decision de no pagar cache cluster 24/7.
  rest_api_id = aws_api_gateway_rest_api.segat.id
  stage_name  = aws_api_gateway_stage.prod.stage_name
  method_path = "*/*"

  settings {
    logging_level      = "INFO"
    metrics_enabled    = true
    data_trace_enabled = false
  }

  depends_on = [aws_api_gateway_account.main]
}

# Reutiliza el mismo WAF que protege el ALB externo (waf.tf)
resource "aws_wafv2_web_acl_association" "api_gateway" {
  resource_arn = aws_api_gateway_stage.prod.arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

