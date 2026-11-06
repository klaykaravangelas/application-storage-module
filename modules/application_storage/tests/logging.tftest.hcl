mock_provider "aws" {}

variables {
  application = "orders"
  environment = "dev"
  name_suffix = "example"
}

run "logging_off_by_default" {
  command = plan

  assert {
    condition     = length(aws_s3_bucket_logging.this) == 0
    error_message = "Server access logging must be off when no destination is supplied."
  }
}

run "logging_enabled" {
  command = plan

  variables {
    access_logging = {
      target_bucket = "central-logs-example"
      target_prefix = "orders/dev/"
    }
  }

  assert {
    condition     = aws_s3_bucket_logging.this[0].target_bucket == "central-logs-example"
    error_message = "Access logs must be sent to the caller's destination bucket."
  }

  assert {
    condition     = aws_s3_bucket_logging.this[0].target_prefix == "orders/dev/"
    error_message = "Access log object keys must use the caller's prefix."
  }
}
