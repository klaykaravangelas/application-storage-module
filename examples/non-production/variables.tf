variable "aws_region" {
  description = "AWS Region for the development bucket."
  type        = string
  default     = "us-west-2"
}

variable "application" {
  description = "Application identifier for the example bucket."
  type        = string
}

variable "environment" {
  description = "Non-production environment identifier."
  type        = string
}

variable "name_suffix" {
  description = "Suffix chosen to make the complete bucket name available in the S3 namespace."
  type        = string
}

variable "tags" {
  description = "Additional application bucket tags."
  type        = map(string)
  default     = {}
}

variable "versioning_status" {
  description = "Bucket versioning status: Enabled or Suspended."
  type        = string
  default     = "Enabled"
}

variable "noncurrent_version_expiration_days" {
  description = "Days to retain noncurrent versions, or null to leave expiration off."
  type        = number
  default     = null
}

variable "create_kms_key" {
  description = "Create a new KMS key for the application bucket instead of supplying an existing key."
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "Optional existing KMS key ARN. Leave null when creating a key or using SSE-S3."
  type        = string
  default     = null
}

variable "access_logging" {
  description = "Optional existing access log destination, prepared according to the module README."
  type = object({
    target_bucket = string
    target_prefix = optional(string, "access-logs/")
  })
  default = null
}
