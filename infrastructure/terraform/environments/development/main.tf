provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.expected_account_id]

  default_tags {
    tags = local.common_tags
  }
}

locals {
  name_prefix = "kelimio-${var.environment}"
  common_tags = {
    Project     = "kelimio"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "networking" {
  source = "../../modules/networking"

  name_prefix             = local.name_prefix
  vpc_cidr                = var.vpc_cidr
  availability_zone_count = 2
  enable_nat_gateway      = var.enable_nat_gateway
  tags                    = local.common_tags
}

module "foundation" {
  source = "../../modules/foundation"

  name_prefix        = local.name_prefix
  environment        = var.environment
  log_retention_days = var.log_retention_days
  tags               = local.common_tags
}
