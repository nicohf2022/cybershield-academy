output "vpc_id" {
  description = "ID of the VPC created for the primary environment."
  value       = try(module.network[0].vpc_id, null)
}

output "public_subnet_id" {
  description = "ID of the public subnet created for the primary environment."
  value       = try(module.network[0].public_subnet_id, null)
}

output "app_security_group_id" {
  description = "ID of the Security Group assigned to the application."
  value       = try(module.network[0].app_security_group_id, null)
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
  value       = try(module.replication[0].role_arn, null)
}
output "ec2_iam_role_name" {
  description = "Name of the IAM Role assigned to the application instance."
  value       = try(module.iam[0].role_name, null)
}

output "ec2_iam_role_arn" {
  description = "ARN of the IAM Role assigned to the application instance."
  value       = try(module.iam[0].role_arn, null)
}

output "ec2_instance_profile_name" {
  description = "Name of the IAM Instance Profile used by the application instance."
  value       = try(module.iam[0].instance_profile_name, null)
}

output "instance_id" {
  description = "ID of the EC2 application instance."
  value       = try(module.compute[0].instance_id, null)
}

output "instance_public_ip" {
  description = "Public IPv4 address assigned to the EC2 application instance."
  value       = try(module.compute[0].public_ip, null)
}

output "instance_public_dns" {
  description = "Public DNS name assigned to the EC2 application instance."
  value       = try(module.compute[0].public_dns, null)
}

output "application_log_group_name" {
  description = "Name of the CloudWatch Log Group for application logs."
  value       = try(module.monitoring[0].log_group_name, null)
}

output "alerts_sns_topic_arn" {
  description = "ARN of the SNS Topic used for operational alerts."
  value       = try(module.monitoring[0].sns_topic_arn, null)
}

output "high_cpu_alarm_name" {
  description = "Name of the CloudWatch alarm that monitors high CPU utilization."
  value       = try(module.monitoring[0].high_cpu_alarm_name, null)
}

output "status_check_alarm_name" {
  description = "Name of the CloudWatch alarm that monitors failed EC2 status checks."
  value       = try(module.monitoring[0].status_check_alarm_name, null)
}

output "backup_s3_prefix" {
  description = "Regional PostgreSQL backup prefix."
  value       = "s3://${module.storage.bucket_name}/postgres"
}
output "application_url" {
  description = "Demo URL, null while compute is disabled."
  value       = var.enable_compute ? "http://${module.compute[0].public_ip}" : null
}
