
# =============================================================================
# environments/dev/main.tf
# Llama una sola vez al wiring compartido de los 14 modulos
# (infraestructure/iac/modules/stack). No agregar aqui logica de modulos --
# eso vive en modules/stack para que dev/qa/prod nunca diverjan.
# =============================================================================

module "segat" {
  source = "../../modules/stack"
  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  aws_region   = var.aws_region
  environment  = var.environment
  project_name = var.project_name

  vpc_cidr               = var.vpc_cidr
  subnet_private_a_cidr  = var.subnet_private_a_cidr
  subnet_private_b_cidr  = var.subnet_private_b_cidr
  subnet_private_c_cidr  = var.subnet_private_c_cidr
  subnet_private_c2_cidr = var.subnet_private_c2_cidr
  subnet_public_cidr     = var.subnet_public_cidr
  subnet_public_b_cidr   = var.subnet_public_b_cidr

  ecs_task_cpu      = var.ecs_task_cpu
  ecs_task_memory   = var.ecs_task_memory
  ecs_desired_count = var.ecs_desired_count
  ecs_min_count     = var.ecs_min_count
  ecs_max_count     = var.ecs_max_count

  hibernate_ddl_auto = var.hibernate_ddl_auto

  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password

  sqs_visibility_timeout = var.sqs_visibility_timeout
  sqs_message_retention  = var.sqs_message_retention
  sqs_dlq_max_receive    = var.sqs_dlq_max_receive
  alert_email            = var.alert_email

  replication_bucket_reportes   = var.replication_bucket_reportes
  replication_bucket_alb        = var.replication_bucket_alb
  replication_bucket_cloudtrail = var.replication_bucket_cloudtrail
  replication_bucket_frontend   = var.replication_bucket_frontend

  domain_name = var.domain_name
  github_repo = var.github_repo

  enable_secrets_rotation       = var.enable_secrets_rotation
  enable_s3_replication         = var.enable_s3_replication
  manage_apigw_account_settings = var.manage_apigw_account_settings
  manage_config_recorder        = var.manage_config_recorder
  manage_oidc_provider          = var.manage_oidc_provider
}
