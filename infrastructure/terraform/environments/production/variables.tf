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
