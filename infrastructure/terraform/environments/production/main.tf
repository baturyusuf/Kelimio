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

  name_prefix             = local.name_prefix
  vpc_cidr                = var.vpc_cidr
  availability_zone_count = 1
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

module "cost_controls" {
  source = "../../modules/cost_controls"

  name_prefix               = local.name_prefix
  environment               = local.environment
  monthly_budget_usd        = 50
  budget_notification_email = var.budget_notification_email
  log_retention_days        = 14
  tags                      = local.common_tags
}
