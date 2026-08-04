variable "name_prefix" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)

  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "API Gateway VPC link requires the production public subnet set."
  }
}

variable "primary_public_subnet_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "RDS requires private subnets in at least two Availability Zones."
  }
}

variable "primary_availability_zone" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "api_ecr_repository_url" {
  type = string
}

variable "api_ecr_repository_arn" {
  type = string
}

variable "api_log_group_name" {
  type = string
}

variable "api_log_group_arn" {
  type = string
}

variable "api_image_digest" {
  description = "Immutable multi-architecture ECR image digest, including the sha256: prefix."
  type        = string

  validation {
    condition     = can(regex("^sha256:[0-9a-f]{64}$", var.api_image_digest))
    error_message = "api_image_digest must be an immutable sha256 image digest."
  }
}

variable "api_desired_count" {
  type    = number
  default = 0

  validation {
    condition     = contains([0, 1], var.api_desired_count)
    error_message = "The ADR-018 beta permits zero or one API task."
  }
}

variable "build_revision" {
  type = string

  validation {
    condition     = can(regex("^[0-9a-f]{40}$", var.build_revision))
    error_message = "build_revision must be the full immutable Git commit SHA."
  }
}

variable "operating_mode_parameter_name" {
  type = string
}

variable "oidc_issuer" {
  type = string
}

variable "oidc_jwk_set_uri" {
  type = string
}

variable "oidc_client_id" {
  type = string
}

variable "operations_topic_arn" {
  type = string
}

variable "database_secret_version" {
  description = "Increment deliberately to rotate the write-only runtime database password."
  type        = number
  default     = 1
}

variable "matching_secret_version" {
  description = "Initial key version. Rotation is intentionally blocked until the retained-key runbook and tool exist."
  type        = number
  default     = 1

  validation {
    condition     = var.matching_secret_version == 1
    error_message = "Type-D replay-key rotation must not discard historical keys; only initial version 1 is currently supported."
  }
}

variable "database_instance_class" {
  type    = string
  default = "db.t4g.micro"

  validation {
    condition     = var.database_instance_class == "db.t4g.micro"
    error_message = "ADR-018 initially permits only db.t4g.micro; scaling requires cost review."
  }
}

variable "database_engine_version" {
  type    = string
  default = "17.5"
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "tags" {
  type    = map(string)
  default = {}
}
