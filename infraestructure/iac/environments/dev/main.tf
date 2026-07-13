
# =============================================================================
# environments/dev/main.tf
# Conecta los 14 modulos de infraestructure/iac/modules/ en orden de
# dependencias. Cada bloque de comentario indica la "capa" (ver plan del
# refactor) para que sea facil ubicar por que un modulo va antes que otro.
# =============================================================================

# ---------------------------------------------------------------------------
# Capa 0 — sin dependencias entre si
# ---------------------------------------------------------------------------
module "security" {
  source = "../../modules/security"

  project_name             = var.project_name
  aws_region                = var.aws_region
  enable_secrets_rotation  = var.enable_secrets_rotation
}

module "messaging" {
  source = "../../modules/messaging"

  project_name            = var.project_name
  sqs_visibility_timeout  = var.sqs_visibility_timeout
  sqs_message_retention   = var.sqs_message_retention
  sqs_dlq_max_receive     = var.sqs_dlq_max_receive
  alert_email             = var.alert_email
}

module "auth" {
  source = "../../modules/auth"

  project_name = var.project_name
}

module "certificates" {
  source = "../../modules/certificates"

  project_name = var.project_name
  domain_name  = var.domain_name
}

# ---------------------------------------------------------------------------
# Capa 1 — depende de security
# ---------------------------------------------------------------------------
module "networking" {
  source = "../../modules/networking"

  project_name            = var.project_name
  vpc_cidr                = var.vpc_cidr
  subnet_public_cidr      = var.subnet_public_cidr
  subnet_public_b_cidr    = var.subnet_public_b_cidr
  subnet_private_a_cidr   = var.subnet_private_a_cidr
  subnet_private_b_cidr   = var.subnet_private_b_cidr
  subnet_private_c_cidr   = var.subnet_private_c_cidr
  subnet_private_c2_cidr  = var.subnet_private_c2_cidr

  kms_secrets_key_arn    = module.security.kms_secrets_key_arn
  ecs_execution_role_arn = module.security.ecs_execution_role_arn
}

# ---------------------------------------------------------------------------
# Capa 2 — depende de networking, security, certificates
# ---------------------------------------------------------------------------
module "database" {
  source = "../../modules/database"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  vpc_id                  = module.networking.vpc_id
  subnet_private_c_id     = module.networking.subnet_private_c_id
  subnet_private_c2_id    = module.networking.subnet_private_c2_id
  route_table_private_id  = module.networking.route_table_private_id
  sg_rds_id               = module.networking.sg_rds_id
  sg_redis_id             = module.networking.sg_redis_id

  rds_monitoring_role_arn = module.security.rds_monitoring_role_arn
  s3_replication_role_arn = module.security.s3_replication_role_arn

  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password

  enable_s3_replication       = var.enable_s3_replication
  replication_bucket_reportes = var.replication_bucket_reportes
}

module "compute" {
  source = "../../modules/compute"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  vpc_id               = module.networking.vpc_id
  subnet_public_a_id   = module.networking.subnet_public_a_id
  subnet_public_b_id   = module.networking.subnet_public_b_id
  subnet_private_a_id  = module.networking.subnet_private_a_id
  subnet_private_b_id  = module.networking.subnet_private_b_id
  sg_alb_id            = module.networking.sg_alb_id
  sg_ecs_tasks_id      = module.networking.sg_ecs_tasks_id

  acm_certificate_arn = module.certificates.acm_certificate_arn

  kms_secrets_key_arn     = module.security.kms_secrets_key_arn
  ecs_execution_role_arn  = module.security.ecs_execution_role_arn
  ecs_task_role_arn       = module.security.ecs_task_role_arn
  s3_replication_role_arn = module.security.s3_replication_role_arn

  secret_db_credentials_arn = module.security.secret_db_credentials_arn
  secret_cloudinary_arn     = module.security.secret_cloudinary_arn
  secret_jwt_arn            = module.security.secret_jwt_arn
  secret_n8n_arn            = module.security.secret_n8n_arn

  ecs_task_cpu      = var.ecs_task_cpu
  ecs_task_memory   = var.ecs_task_memory
  ecs_desired_count = var.ecs_desired_count
  ecs_min_count     = var.ecs_min_count
  ecs_max_count     = var.ecs_max_count

  enable_s3_replication  = var.enable_s3_replication
  replication_bucket_alb = var.replication_bucket_alb
}

# ---------------------------------------------------------------------------
# Capa 3 — depende de compute (+ security/certificates)
# ---------------------------------------------------------------------------
module "firewall" {
  source = "../../modules/firewall"
  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  project_name         = var.project_name
  alb_external_arn     = module.compute.alb_external_arn
  kms_secrets_key_arn  = module.security.kms_secrets_key_arn
}

module "vpc_link" {
  source = "../../modules/vpc_link"

  project_name         = var.project_name
  vpc_id               = module.networking.vpc_id
  vpc_cidr             = var.vpc_cidr
  subnet_private_a_id  = module.networking.subnet_private_a_id
  subnet_private_b_id  = module.networking.subnet_private_b_id
  sg_ecs_tasks_id      = module.networking.sg_ecs_tasks_id
  alb_internal_arn     = module.compute.alb_internal_arn
  alb_logs_bucket_id   = module.compute.alb_logs_bucket_id
}

module "dns" {
  source = "../../modules/dns"

  project_name           = var.project_name
  domain_name            = var.domain_name
  alb_external_dns_name  = module.compute.alb_external_dns_name
  alb_external_zone_id   = module.compute.alb_external_zone_id
}

module "cdn" {
  source = "../../modules/cdn"

  project_name = var.project_name
  environment  = var.environment

  alb_external_dns_name       = module.compute.alb_external_dns_name
  alb_internal_dns_name       = module.compute.alb_internal_dns_name
  alb_logs_bucket_id          = module.compute.alb_logs_bucket_id
  alb_logs_bucket_domain_name = module.compute.alb_logs_bucket_domain_name

  acm_certificate_arn = module.certificates.acm_certificate_arn
  waf_cloudfront_arn  = module.firewall.waf_cloudfront_arn

  s3_replication_role_arn     = module.security.s3_replication_role_arn
  enable_s3_replication       = var.enable_s3_replication
  replication_bucket_frontend = var.replication_bucket_frontend
}

# ---------------------------------------------------------------------------
# Capa 4 — depende de vpc_link, compute, auth, firewall
# ---------------------------------------------------------------------------
module "api_gateway" {
  source = "../../modules/api_gateway"

  project_name = var.project_name
  environment  = var.environment

  cognito_user_pool_arn        = module.auth.user_pool_arn
  internal_nlb_dns_name        = module.vpc_link.internal_nlb_dns_name
  vpc_link_id                  = module.vpc_link.vpc_link_id
  cloudwatch_log_group_ecs_arn = module.compute.cloudwatch_log_group_ecs_arn
  waf_main_arn                 = module.firewall.waf_main_arn
}

# ---------------------------------------------------------------------------
# Capa 5 — depende de security, database, compute, messaging
# ---------------------------------------------------------------------------
module "observability" {
  source = "../../modules/observability"

  project_name = var.project_name
  environment  = var.environment

  kms_secrets_key_arn      = module.security.kms_secrets_key_arn
  secret_db_credentials_id = module.security.secret_db_credentials_id

  db_instance_address = module.database.db_instance_address
  db_username         = var.db_username
  db_password         = var.db_password
  db_name             = var.db_name

  ecs_cluster_name = module.compute.ecs_cluster_name
  ecs_service_name = module.compute.ecs_service_name

  sns_alertas_arn        = module.messaging.sns_alertas_arn
  sns_alertas_policy_id  = module.messaging.sns_alertas_policy_id
  sqs_reportes_dlq_name  = module.messaging.sqs_reportes_dlq_name

  s3_replication_role_arn      = module.security.s3_replication_role_arn
  enable_s3_replication        = var.enable_s3_replication
  replication_bucket_cloudtrail = var.replication_bucket_cloudtrail
}

# ---------------------------------------------------------------------------
# Capa 6 — depende de cdn, compute
# ---------------------------------------------------------------------------
module "oidc" {
  source = "../../modules/oidc"

  project_name = var.project_name
  github_repo  = var.github_repo

  ecr_repository_arn          = module.compute.ecr_repository_arn
  s3_frontend_bucket_arn      = module.cdn.s3_frontend_bucket_arn
  cloudfront_distribution_arn = module.cdn.cloudfront_distribution_arn
}

