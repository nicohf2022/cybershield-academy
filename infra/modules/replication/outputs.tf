output "role_arn" {
  description = "Service role used by S3 to replicate the backup prefix."
  value       = aws_iam_role.replication.arn
}

