variable "name_prefix" {
  type = string
}

variable "environment" {
  type = string
}

variable "monthly_budget_usd" {
  type    = number
  default = 50

  validation {
    condition     = var.monthly_budget_usd > 0 && var.monthly_budget_usd <= 50
    error_message = "ADR-018 requires a positive monthly budget no greater than USD 50."
  }
}

variable "budget_notification_email" {
  description = "Owner-controlled operations address. SNS requires one-time confirmation before email delivery starts."
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.budget_notification_email))
    error_message = "budget_notification_email must be a valid nonblank email address."
  }
}

variable "operating_mode_parameter_name" {
  type    = string
  default = "/kelimio/production/operating-mode"
}

variable "suspendible_ec2_instance_ids" {
  type    = list(string)
  default = []
}

variable "suspendible_rds_instance_identifiers" {
  type    = list(string)
  default = []
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "tags" {
  type    = map(string)
  default = {}
}
