terraform {
  required_version = "= 1.15.8"

  backend "s3" {}

  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "= 2.8.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }
}
