mock_provider "aws" {}

variables {
  application = "orders"
  environment = "dev"
  name_suffix = "example"
}

run "secure_defaults" {
  command = plan

  override_resource {
    target          = aws_s3_bucket.this
    override_during = plan
    values = {
      id  = "orders-dev-example"
      arn = "arn:aws:s3:::orders-dev-example"
    }
  }

  assert {
    condition = alltrue([
      for rule in aws_s3_bucket_server_side_encryption_configuration.this.rule :
      rule.apply_server_side_encryption_by_default[0].sse_algorithm == "AES256"
    ]) && length(aws_s3_bucket_server_side_encryption_configuration.this.rule) == 1
    error_message = "The application bucket must have one SSE-S3 default encryption rule."
  }

  assert {
    condition     = length(aws_kms_key.this) == 0 && output.kms_key_arn == null
    error_message = "The default SSE-S3 configuration must not create or select a KMS key."
  }

  assert {
    condition = (
      aws_s3_bucket_public_access_block.this.block_public_acls &&
      aws_s3_bucket_public_access_block.this.ignore_public_acls &&
      aws_s3_bucket_public_access_block.this.block_public_policy &&
      aws_s3_bucket_public_access_block.this.restrict_public_buckets
    )
    error_message = "All four public access block settings must be enabled."
  }

  assert {
    condition = (
      jsondecode(aws_s3_bucket_policy.this.policy).Statement[0].Effect == "Deny" &&
      jsondecode(aws_s3_bucket_policy.this.policy).Statement[0].Principal == "*" &&
      jsondecode(aws_s3_bucket_policy.this.policy).Statement[0].Action == "s3:*"
    )
    error_message = "The bucket policy must deny all S3 operations for all principals when its conditions match."
  }

  assert {
    condition = toset(jsondecode(aws_s3_bucket_policy.this.policy).Statement[0].Resource) == toset([
      "arn:aws:s3:::orders-dev-example",
      "arn:aws:s3:::orders-dev-example/*",
    ])
    error_message = "The transport policy must cover both the bucket and its objects."
  }

  assert {
    condition = jsondecode(aws_s3_bucket_policy.this.policy).Statement[0].Condition == {
      Bool = {
        "aws:SecureTransport"       = "false"
        "aws:PrincipalIsAWSService" = "false"
      }
    }
    error_message = "The policy must deny HTTP for non-service principals and exclude direct AWS service principals."
  }
}

run "kms_encryption" {
  command = plan

  variables {
    kms_key_arn = "arn:aws:kms:us-west-2:111122223333:key/12345678-1234-1234-1234-123456789012"
  }

  assert {
    condition = alltrue([
      for rule in aws_s3_bucket_server_side_encryption_configuration.this.rule :
      rule.apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms" &&
      rule.apply_server_side_encryption_by_default[0].kms_master_key_id == var.kms_key_arn
    ]) && length(aws_s3_bucket_server_side_encryption_configuration.this.rule) == 1
    error_message = "Supplying a KMS key ARN must configure SSE-KMS with that key."
  }

  assert {
    condition     = length(aws_kms_key.this) == 0 && output.kms_key_arn == var.kms_key_arn
    error_message = "An existing key must be reused and exposed without creating another key."
  }
}

run "generated_kms_key" {
  command = plan

  variables {
    create_kms_key = true
  }

  override_resource {
    target          = aws_kms_key.this[0]
    override_during = plan
    values = {
      arn = "arn:aws:kms:us-west-2:111122223333:key/87654321-4321-4321-4321-210987654321"
    }
  }

  assert {
    condition = (
      length(aws_kms_key.this) == 1 &&
      aws_kms_key.this[0].enable_key_rotation &&
      aws_kms_key.this[0].deletion_window_in_days == 30 &&
      aws_kms_key.this[0].tags == aws_s3_bucket.this.tags
    )
    error_message = "The generated key must use rotation, a 30-day deletion window, and the application bucket's tags."
  }

  assert {
    condition = alltrue([
      for rule in aws_s3_bucket_server_side_encryption_configuration.this.rule :
      rule.apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms" &&
      rule.apply_server_side_encryption_by_default[0].kms_master_key_id == aws_kms_key.this[0].arn
    ]) && length(aws_s3_bucket_server_side_encryption_configuration.this.rule) == 1
    error_message = "SSE-KMS must use the generated key."
  }

  assert {
    condition     = output.kms_key_arn == aws_kms_key.this[0].arn
    error_message = "The key ARN output must expose the generated key."
  }
}

run "reject_conflicting_kms_options" {
  command = plan

  variables {
    create_kms_key = true
    kms_key_arn    = "arn:aws:kms:us-west-2:111122223333:key/12345678-1234-1234-1234-123456789012"
  }

  expect_failures = [var.create_kms_key]
}
