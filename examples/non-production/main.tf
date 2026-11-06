module "application_storage" {
  source = "../../modules/application_storage"

  application = var.application
  environment = var.environment
  name_suffix = var.name_suffix

  versioning_status                  = var.versioning_status
  noncurrent_version_expiration_days = var.noncurrent_version_expiration_days
  create_kms_key                     = var.create_kms_key
  kms_key_arn                        = var.kms_key_arn
  access_logging                     = var.access_logging

  tags = var.tags
}
