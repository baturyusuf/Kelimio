variable "name_prefix" {
  type = string
}

variable "environment" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "callback_urls" {
  type = list(string)

  validation {
    condition     = length(var.callback_urls) > 0 && alltrue([for value in var.callback_urls : can(regex("^[a-z][a-z0-9+.-]*:/", value))])
    error_message = "callback_urls must contain at least one absolute redirect URI."
  }
}

variable "logout_urls" {
  type = list(string)

  validation {
    condition     = length(var.logout_urls) > 0 && alltrue([for value in var.logout_urls : can(regex("^[a-z][a-z0-9+.-]*:/", value))])
    error_message = "logout_urls must contain at least one absolute redirect URI."
  }
}

variable "domain_prefix" {
  type = string

  validation {
    condition     = can(regex("^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$", var.domain_prefix))
    error_message = "domain_prefix must be a valid lower-case Cognito domain prefix."
  }
}

variable "google_identity_enabled" {
  type    = bool
  default = false
}

variable "google_identity_configuration_version" {
  description = "Non-secret operator-controlled version that deliberately reapplies a rotated Google client secret."
  type        = string
  default     = "not-configured"
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "tags" {
  type    = map(string)
  default = {}
}
