variable "aws_region" {
  description = "ADR-018 initial production Region."
  type        = string
  default     = "eu-central-1"

  validation {
    condition     = var.aws_region == "eu-central-1"
    error_message = "ADR-018 fixes the initial production Region to eu-central-1. A change requires a superseding ADR."
  }
}

variable "expected_account_id" {
  description = "Owner-confirmed production AWS account ID."
  type        = string
  default     = "923300948109"

  validation {
    condition     = var.expected_account_id == "923300948109"
    error_message = "This production root can operate only in owner-approved account 923300948109."
  }
}

variable "budget_notification_email" {
  description = "Owner-controlled address that confirms and receives AWS cost notifications."
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.budget_notification_email))
    error_message = "budget_notification_email must be a valid nonblank email address."
  }
}

variable "import_archive_retention_days" {
  description = "Owner-approved compliance retention for original course workbooks."
  type        = number

  validation {
    condition     = var.import_archive_retention_days >= 1 && var.import_archive_retention_days <= 3650
    error_message = "import_archive_retention_days must be between 1 and 3650 days."
  }
}

variable "vpc_cidr" {
  type    = string
  default = "10.50.0.0/16"
}

variable "google_identity_enabled" {
  description = "Enables the Google IdP only after the owner has populated the emitted Secrets Manager secret."
  type        = bool
  default     = false
}

variable "google_identity_configuration_version" {
  description = "Non-secret rotation marker; increment after changing the Google OIDC secret."
  type        = string
  default     = "not-configured"
}

variable "api_image_digest" {
  description = "Immutable ARM64 backend image digest already present in the production ECR repository."
  type        = string

  validation {
    condition     = can(regex("^sha256:[0-9a-f]{64}$", var.api_image_digest))
    error_message = "api_image_digest must be an immutable sha256 image digest."
  }
}

variable "worker_image_digest" {
  description = "Immutable X86_64 import-worker backend image digest."
  type        = string
  validation {
    condition     = can(regex("^sha256:[0-9a-f]{64}$", var.worker_image_digest))
    error_message = "worker_image_digest must be an immutable sha256 image digest."
  }
}

variable "scanner_image_digest" {
  description = "Immutable X86_64 ClamAV scanner image digest."
  type        = string
  validation {
    condition     = can(regex("^sha256:[0-9a-f]{64}$", var.scanner_image_digest))
    error_message = "scanner_image_digest must be an immutable sha256 image digest."
  }
}

variable "production_teacher_features_enabled" {
  description = "Server-side release gate for authenticated, authorized teacher import."
  type        = bool
  default     = false
}

variable "build_revision" {
  description = "Full Git commit SHA used to build the backend image."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{40}$", var.build_revision))
    error_message = "build_revision must be a full Git commit SHA."
  }
}

variable "api_desired_count" {
  description = "Keep zero until the migration task succeeds; the release workflow then sets one."
  type        = number
  default     = 0

  validation {
    condition     = contains([0, 1], var.api_desired_count)
    error_message = "api_desired_count must be zero or one."
  }
}

variable "database_secret_version" {
  type    = number
  default = 1
}

variable "worker_database_secret_version" {
  type    = number
  default = 1
}

variable "import_cursor_secret_version" {
  type    = number
  default = 1
}

variable "matching_secret_version" {
  type    = number
  default = 1

  validation {
    condition     = var.matching_secret_version == 1
    error_message = "Matching replay-key rotation remains blocked until historical-key retention tooling is implemented."
  }
}
