variable "aws_region" {
  description = "Owner-confirmed AWS region. No default is intentional."
  type        = string

  validation {
    condition     = length(trimspace(var.aws_region)) > 0
    error_message = "aws_region must be explicitly provided."
  }
}

variable "environment" {
  type    = string
  default = "development"

  validation {
    condition     = var.environment == "development"
    error_message = "This state root is fixed to the development environment."
  }
}

variable "expected_account_id" {
  description = "Owner-confirmed 12-digit AWS account ID allowed for this development root."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.expected_account_id))
    error_message = "expected_account_id must be an explicit 12-digit AWS account ID."
  }
}

variable "vpc_cidr" {
  type    = string
  default = "10.40.0.0/16"
}

variable "enable_nat_gateway" {
  description = "NAT is required for the standard private-service topology but has a cost."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  type    = number
  default = 30
}
