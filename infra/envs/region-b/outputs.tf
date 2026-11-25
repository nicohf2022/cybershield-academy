output "backup_bucket_name" {
  description = "Recovery bucket; pass this name to Region A if overriding the default."
  value       = module.storage.bucket_name
}

output "backup_bucket_arn" {
  description = "ARN of the recovery backup bucket."
  value       = module.storage.bucket_arn
}

output "backup_s3_prefix" {
  description = "S3 prefix used by the restore script for latest-backup selection."
  value       = "s3://${module.storage.bucket_name}/postgres"
}
