provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.expected_account_id]

  default_tags {
    tags = local.common_tags
  }
}

locals {
  environment = "production"
  name_prefix = "kelimio-${local.environment}"
  common_tags = {
    Project     = "kelimio"
    Environment = local.environment
    ManagedBy   = "terraform"
    CostPolicy  = "adr-018"
  }
}

module "networking" {
  source = "../../modules/networking"

  name_prefix = local.name_prefix
  vpc_cidr    = var.vpc_cidr
  # RDS requires subnet-group coverage in at least two AZs even for Single-AZ.
  # No standby database or second API task is provisioned by this setting.
  availability_zone_count = 2
  enable_nat_gateway      = false
  tags                    = local.common_tags
}

module "foundation" {
  source = "../../modules/foundation"

  name_prefix                   = local.name_prefix
  environment                   = local.environment
  log_retention_days            = 14
  import_archive_retention_days = var.import_archive_retention_days
  ecr_image_retention_count     = 10
  tags                          = local.common_tags
}

module "identity" {
  source = "../../modules/identity"

  name_prefix                           = local.name_prefix
  environment                           = local.environment
  kms_key_arn                           = module.foundation.kms_key_arn
  callback_urls                         = ["com.kelimio.app:/oauthredirect"]
  logout_urls                           = ["com.kelimio.app:/logout"]
  domain_prefix                         = "kelimio-${var.expected_account_id}-production"
  google_identity_enabled               = var.google_identity_enabled
  google_identity_configuration_version = var.google_identity_configuration_version
  log_retention_days                    = 14
  tags                                  = local.common_tags
}

module "cost_controls" {
  source = "../../modules/cost_controls"

  name_prefix               = local.name_prefix
  environment               = local.environment
  kms_key_arn               = module.foundation.kms_key_arn
  monthly_budget_usd        = 50
  budget_notification_email = var.budget_notification_email
  log_retention_days        = 14
  suspendible_ecs_services = [{
    cluster = "${local.name_prefix}-cluster"
    service = "${local.name_prefix}-api"
    }, {
    cluster = "${local.name_prefix}-cluster"
    service = "${local.name_prefix}-import-worker"
  }]
  suspendible_rds_instance_identifiers = ["${local.name_prefix}-postgres"]
  tags                                 = local.common_tags
}

module "runtime" {
  source = "../../modules/runtime"

  name_prefix                         = local.name_prefix
  environment                         = local.environment
  aws_region                          = var.aws_region
  vpc_id                              = module.networking.vpc_id
  vpc_cidr                            = var.vpc_cidr
  public_subnet_ids                   = module.networking.public_subnet_ids
  primary_public_subnet_id            = module.networking.public_subnet_ids[0]
  private_subnet_ids                  = module.networking.private_subnet_ids
  primary_availability_zone           = module.networking.availability_zones[0]
  kms_key_arn                         = module.foundation.kms_key_arn
  api_ecr_repository_url              = module.foundation.ecr_repository_urls["api"]
  api_ecr_repository_arn              = module.foundation.ecr_repository_arns["api"]
  api_log_group_name                  = module.foundation.log_group_names["api"]
  api_log_group_arn                   = module.foundation.log_group_arns["api"]
  worker_ecr_repository_url           = module.foundation.ecr_repository_urls["worker"]
  worker_ecr_repository_arn           = module.foundation.ecr_repository_arns["worker"]
  scanner_ecr_repository_url          = module.foundation.ecr_repository_urls["scanner"]
  scanner_ecr_repository_arn          = module.foundation.ecr_repository_arns["scanner"]
  worker_log_group_name               = module.foundation.log_group_names["worker"]
  worker_log_group_arn                = module.foundation.log_group_arns["worker"]
  scanner_log_group_name              = module.foundation.log_group_names["scanner"]
  scanner_log_group_arn               = module.foundation.log_group_arns["scanner"]
  import_quarantine_bucket_name       = module.foundation.bucket_names["import-quarantine"]
  import_quarantine_bucket_arn        = module.foundation.bucket_arns["import-quarantine"]
  import_archive_bucket_name          = module.foundation.bucket_names["import-archive"]
  import_archive_bucket_arn           = module.foundation.bucket_arns["import-archive"]
  import_queue_name                   = module.foundation.import_queue_name
  import_queue_arn                    = module.foundation.import_queue_arn
  import_dlq_name                     = module.foundation.import_dlq_name
  import_dlq_arn                      = module.foundation.import_dlq_arn
  api_image_digest                    = var.api_image_digest
  worker_image_digest                 = var.worker_image_digest
  scanner_image_digest                = var.scanner_image_digest
  api_desired_count                   = var.api_desired_count
  production_teacher_features_enabled = var.production_teacher_features_enabled
  build_revision                      = var.build_revision
  operating_mode_parameter_name       = module.cost_controls.operating_mode_parameter_name
  oidc_issuer                         = module.identity.issuer
  oidc_jwk_set_uri                    = module.identity.jwk_set_uri
  oidc_client_id                      = module.identity.android_client_id
  operations_topic_arn                = module.cost_controls.operations_topic_arn
  database_secret_version             = var.database_secret_version
  worker_database_secret_version      = var.worker_database_secret_version
  import_cursor_secret_version        = var.import_cursor_secret_version
  matching_secret_version             = var.matching_secret_version
  log_retention_days                  = 14
  tags                                = local.common_tags
}
