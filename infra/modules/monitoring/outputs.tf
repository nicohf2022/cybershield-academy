output "log_group_name" {
  description = "Name of the CloudWatch Log Group for application logs."
  value       = aws_cloudwatch_log_group.application.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch Log Group for application logs."
  value       = aws_cloudwatch_log_group.application.arn
}

output "sns_topic_name" {
  description = "Name of the SNS Topic used for operational alerts."
  value       = aws_sns_topic.alerts.name
}

output "sns_topic_arn" {
  description = "ARN of the SNS Topic used for operational alerts."
  value       = aws_sns_topic.alerts.arn
}

output "high_cpu_alarm_name" {
  description = "Name of the CloudWatch alarm that monitors high CPU utilization."
  value       = aws_cloudwatch_metric_alarm.high_cpu.alarm_name
}

output "high_cpu_alarm_arn" {
  description = "ARN of the CloudWatch alarm that monitors high CPU utilization."
  value       = aws_cloudwatch_metric_alarm.high_cpu.arn
}

output "status_check_alarm_name" {
  description = "Name of the CloudWatch alarm that monitors failed EC2 status checks."
  value       = aws_cloudwatch_metric_alarm.status_check_failed.alarm_name
}

output "status_check_alarm_arn" {
  description = "ARN of the CloudWatch alarm that monitors failed EC2 status checks."
  value       = aws_cloudwatch_metric_alarm.status_check_failed.arn
}
