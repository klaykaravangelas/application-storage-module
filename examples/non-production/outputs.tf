output "bucket_name" {
  description = "Name of the development application bucket."
  value       = module.application_storage.bucket_name
}

output "bucket_arn" {
  description = "ARN of the development application bucket."
  value       = module.application_storage.bucket_arn
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the development application bucket."
  value       = module.application_storage.bucket_regional_domain_name
}

output "kms_key_arn" {
  description = "ARN of the application's created or supplied KMS key, or null for SSE-S3."
  value       = module.application_storage.kms_key_arn
}
