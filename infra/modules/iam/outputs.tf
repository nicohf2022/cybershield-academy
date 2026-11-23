output "role_name" {
  description = "Name of the IAM role assumed by the EC2 application instance."
  value       = aws_iam_role.ec2.name
}

output "role_arn" {
  description = "ARN of the IAM role assumed by the EC2 application instance."
  value       = aws_iam_role.ec2.arn
}

output "instance_profile_name" {
  description = "Name of the IAM Instance Profile to associate with the EC2 instance."
  value       = aws_iam_instance_profile.ec2.name
}

output "instance_profile_arn" {
  description = "ARN of the IAM Instance Profile associated with the EC2 role."
  value       = aws_iam_instance_profile.ec2.arn
}

output "backup_policy_arn" {
  description = "ARN of the least-privilege IAM policy for S3 backup access."
  value       = aws_iam_policy.backup_access.arn
}
