mock_provider "aws" {}

run "non_production_example" {
  command = plan

  variables {
    aws_region  = "us-west-2"
    application = "orders"
    environment = "dev"
    name_suffix = "example"

    tags = {
      Owner = "application-team"
    }

    versioning_status                  = "Enabled"
    noncurrent_version_expiration_days = 30
    create_kms_key                     = true
    kms_key_arn                        = null
    access_logging                     = null
  }

  override_resource {
    target          = module.application_storage.aws_kms_key.this[0]
    override_during = plan
    values = {
      arn = "arn:aws:kms:us-west-2:111122223333:key/87654321-4321-4321-4321-210987654321"
    }
  }

  assert {
    condition     = output.bucket_name == "orders-dev-example"
    error_message = "The example must consume the application_storage module and expose its development bucket name."
  }

  assert {
    condition     = output.kms_key_arn == "arn:aws:kms:us-west-2:111122223333:key/87654321-4321-4321-4321-210987654321"
    error_message = "The example must create a KMS key and expose its ARN."
  }
}
