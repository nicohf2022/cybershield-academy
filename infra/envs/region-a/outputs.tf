output "vpc_id" {
  description = "ID of the VPC created for the primary environment."
  value       = module.network.vpc_id
}

output "public_subnet_id" {
  description = "ID of the public subnet created for the primary environment."
  value       = module.network.public_subnet_id
}

output "app_security_group_id" {
  description = "ID of the Security Group assigned to the application."
  value       = module.network.app_security_group_id
}
output "backup_bucket_name" {
  description = "Name of the S3 bucket used for PostgreSQL backups."
  value       = module.storage.bucket_name
}

output "backup_bucket_arn" {
  description = "ARN of the S3 bucket used for PostgreSQL backups."
  value       = module.storage.bucket_arn
}

output "recovery_backup_bucket_name" {
  description = "Destination bucket name expected by the replication configuration."
  value       = local.recovery_backup_bucket_name
}

output "replication_role_arn" {
  description = "Service role that copies PostgreSQL backups to Region B."
  value       = module.replication.role_arn
}
output "ec2_iam_role_name" {
  description = "Name of the IAM Role assigned to the application instance."
  value       = module.iam.role_name
}

output "ec2_iam_role_arn" {
  description = "ARN of the IAM Role assigned to the application instance."
  value       = module.iam.role_arn
}

output "ec2_instance_profile_name" {
  description = "Name of the IAM Instance Profile used by the application instance."
  value       = module.iam.instance_profile_name
}

output "instance_id" {
  description = "ID of the EC2 application instance."
  value       = module.compute.instance_id
}

output "instance_public_ip" {
  description = "Public IPv4 address assigned to the EC2 application instance."
  value       = module.compute.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name assigned to the EC2 application instance."
  value       = module.compute.public_dns
}

output "application_log_group_name" {
  description = "Name of the CloudWatch Log Group for application logs."
  value       = module.monitoring.log_group_name
}

output "alerts_sns_topic_arn" {
  description = "ARN of the SNS Topic used for operational alerts."
  value       = module.monitoring.sns_topic_arn
}

output "high_cpu_alarm_name" {
  description = "Name of the CloudWatch alarm that monitors high CPU utilization."
  value       = module.monitoring.high_cpu_alarm_name
}

output "status_check_alarm_name" {
  description = "Name of the CloudWatch alarm that monitors failed EC2 status checks."
  value       = module.monitoring.status_check_alarm_name
}
