variable "application" {
  description = "Application identifier used in the bucket name."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.application))
    error_message = "Application must contain only lowercase letters, digits, and hyphens, and must start and end with a letter or digit."
  }
}

variable "environment" {
  description = "Environment identifier used in the bucket name."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.environment))
    error_message = "Environment must contain only lowercase letters, digits, and hyphens, and must start and end with a letter or digit."
  }
}

variable "name_suffix" {
  description = "Caller-chosen suffix to help make the bucket name unique."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.name_suffix))
    error_message = "Name suffix must contain only lowercase letters, digits, and hyphens, and must start and end with a letter or digit."
  }
}

variable "tags" {
  description = "Additional bucket tags. Application, Environment, and ManagedBy are controlled by the module."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "create_kms_key" {
  description = "Create a KMS key for application bucket encryption. Cannot be combined with kms_key_arn."
  type        = bool
  default     = false
  nullable    = false

  validation {
    condition     = !var.create_kms_key || var.kms_key_arn == null
    error_message = "kms_key_arn must be null when create_kms_key is true."
  }
}

variable "kms_key_arn" {
  description = "Existing KMS key ARN for application bucket encryption. Null uses SSE-S3 unless create_kms_key is true."
  type        = string
  default     = null

  validation {
    condition     = var.kms_key_arn == null ? true : trimspace(var.kms_key_arn) != ""
    error_message = "KMS key ARN must be null or a non-empty key ARN."
  }
}

variable "versioning_status" {
  description = "Bucket versioning status: Enabled or Suspended."
  type        = string
  default     = "Enabled"
  nullable    = false

  validation {
    condition     = contains(["Enabled", "Suspended"], var.versioning_status)
    error_message = "Versioning status must be Enabled or Suspended."
  }
}

variable "noncurrent_version_expiration_days" {
  description = "Days to retain noncurrent object versions before permanent deletion. Null disables expiration."
  type        = number
  default     = null

  validation {
    condition = var.noncurrent_version_expiration_days == null ? true : (
      var.noncurrent_version_expiration_days > 0 &&
      floor(var.noncurrent_version_expiration_days) == var.noncurrent_version_expiration_days
    )
    error_message = "Noncurrent version expiration days must be null or a positive whole number."
  }
}

variable "access_logging" {
  description = "Optional server access logging destination. The caller manages the target bucket and its delivery permissions."
  type = object({
    target_bucket = string
    target_prefix = optional(string, "access-logs/")
  })
  default = null

  validation {
    condition     = var.access_logging == null ? true : try(trimspace(var.access_logging.target_bucket) != "", false)
    error_message = "Access logging must specify a non-empty target bucket name."
  }
}
