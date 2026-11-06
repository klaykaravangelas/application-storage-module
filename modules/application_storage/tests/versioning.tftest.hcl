mock_provider "aws" {}

variables {
  application = "orders"
  environment = "dev"
  name_suffix = "example"
}

run "versioning_and_retention_defaults" {
  command = plan

  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Enabled"
    error_message = "Versioning must be enabled by default."
  }

  assert {
    condition     = length(aws_s3_bucket_lifecycle_configuration.this) == 0
    error_message = "Noncurrent version expiration must be off unless a retention period is supplied."
  }
}

run "configured_versioning_and_retention" {
  command = plan

  variables {
    versioning_status                  = "Suspended"
    noncurrent_version_expiration_days = 30
  }

  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Suspended"
    error_message = "The caller must be able to suspend versioning."
  }

  assert {
    condition = (
      aws_s3_bucket_lifecycle_configuration.this[0].rule[0].status == "Enabled" &&
      aws_s3_bucket_lifecycle_configuration.this[0].rule[0].noncurrent_version_expiration[0].noncurrent_days == 30
    )
    error_message = "Supplying 30 days must enable expiration of noncurrent versions after that period."
  }

  assert {
    condition     = length(aws_s3_bucket_lifecycle_configuration.this[0].rule[0].expiration) == 0
    error_message = "The retention rule must not expire current object versions."
  }
}
