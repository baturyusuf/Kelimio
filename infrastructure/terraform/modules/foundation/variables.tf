variable "name_prefix" {
  type = string
}

variable "environment" {
  type = string
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "import_archive_retention_days" {
  description = "Compliance-mode Object Lock retention for immutable import originals; null keeps Object Lock disabled outside production."
  type        = number
  default     = null

  validation {
    condition     = var.import_archive_retention_days == null || (var.import_archive_retention_days >= 1 && var.import_archive_retention_days <= 3650)
    error_message = "import_archive_retention_days must be null or between 1 and 3650 days."
  }
}

variable "ecr_image_retention_count" {
  type    = number
  default = 50

  validation {
    condition     = var.ecr_image_retention_count >= 3 && var.ecr_image_retention_count <= 100
    error_message = "ecr_image_retention_count must be between 3 and 100."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
