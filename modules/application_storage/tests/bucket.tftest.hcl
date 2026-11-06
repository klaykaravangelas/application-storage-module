mock_provider "aws" {}

run "bucket_basics" {
  command = plan

  variables {
    application = "orders"
    environment = "dev"
    name_suffix = "example"
  }

  assert {
    condition     = aws_s3_bucket.this.bucket == "orders-dev-example"
    error_message = "The bucket name must include the application, environment, and suffix."
  }

  assert {
    condition     = aws_s3_bucket.this.force_destroy == false
    error_message = "The module must not automatically empty the bucket during destruction."
  }

  assert {
    condition = aws_s3_bucket.this.tags == tomap({
      Application = "orders"
      Environment = "dev"
      ManagedBy   = "Terraform"
    })
    error_message = "The bucket must carry the standard application, environment, and management tags."
  }
}

run "custom_tags_preserve_standards" {
  command = plan

  variables {
    application = "orders"
    environment = "dev"
    name_suffix = "example"
    tags = {
      Owner       = "platform"
      Application = "another-app"
      Environment = "production"
      ManagedBy   = "manual"
    }
  }

  assert {
    condition = aws_s3_bucket.this.tags == tomap({
      Owner       = "platform"
      Application = "orders"
      Environment = "dev"
      ManagedBy   = "Terraform"
    })
    error_message = "Custom tags must be preserved while the standard module tags take precedence."
  }
}
