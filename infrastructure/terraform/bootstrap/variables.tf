variable "aws_region" {
  description = "ADR-018 production Region."
  type        = string
  default     = "eu-central-1"

  validation {
    condition     = var.aws_region == "eu-central-1"
    error_message = "ADR-018 fixes the initial production Region to eu-central-1."
  }
}

variable "expected_account_id" {
  description = "Owner-confirmed production AWS account ID."
  type        = string
  default     = "923300948109"

  validation {
    condition     = var.expected_account_id == "923300948109"
    error_message = "Bootstrap can operate only in owner-approved account 923300948109."
  }
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for encrypted Terraform state."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.state_bucket_name))
    error_message = "state_bucket_name must be a valid lowercase S3 bucket name."
  }
}

variable "github_repository" {
  description = "Exact GitHub owner/repository allowed to request production OIDC credentials."
  type        = string
  default     = "baturyusuf/Kelimio"

  validation {
    condition     = var.github_repository == "baturyusuf/Kelimio"
    error_message = "The initial production OIDC trust is restricted to baturyusuf/Kelimio."
  }
}

variable "github_oidc_subject_prefix" {
  description = "GitHub immutable OIDC repository subject prefix including owner and repository IDs."
  type        = string
  default     = "repo:baturyusuf@75681771/Kelimio@1307479021"

  validation {
    condition     = var.github_oidc_subject_prefix == "repo:baturyusuf@75681771/Kelimio@1307479021"
    error_message = "The production trust must use the immutable owner/repository IDs returned by GitHub for baturyusuf/Kelimio."
  }
}

variable "github_environment" {
  description = "Protected GitHub Environment encoded into the OIDC subject."
  type        = string
  default     = "production"

  validation {
    condition     = var.github_environment == "production"
    error_message = "Production AWS trust is restricted to the protected production environment."
  }
}
