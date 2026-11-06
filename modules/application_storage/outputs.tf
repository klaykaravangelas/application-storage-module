output "bucket_name" {
  description = "Name of the application data bucket."
  value       = aws_s3_bucket.this.bucket
}

output "bucket_arn" {
  description = "ARN of the application data bucket for consumer IAM policies."
  value       = aws_s3_bucket.this.arn
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the application data bucket."
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}

output "kms_key_arn" {
  description = "ARN of the created or supplied KMS key, or null when using SSE-S3."
  value       = local.kms_key_arn
}
