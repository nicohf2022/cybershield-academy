locals {
  log_group_name          = "/cybershield/${var.name_prefix}/application"
  sns_topic_name          = "${var.name_prefix}-alerts"
  high_cpu_alarm_name     = "${var.name_prefix}-high-cpu"
  status_check_alarm_name = "${var.name_prefix}-status-check-failed"
}

resource "aws_cloudwatch_log_group" "application" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Component = "Monitoring"
    Name      = local.log_group_name
    Purpose   = "ApplicationLogs"
  })
}

resource "aws_sns_topic" "alerts" {
  name = local.sns_topic_name

  tags = merge(var.tags, {
    Component = "Monitoring"
    Name      = local.sns_topic_name
    Purpose   = "OperationalAlerts"
  })
}

resource "aws_sns_topic_subscription" "email" {
  for_each = var.notification_email_addresses

  protocol  = "email"
  topic_arn = aws_sns_topic.alerts.arn
  endpoint  = each.value
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = local.high_cpu_alarm_name
  alarm_description   = "Average EC2 CPU utilization is at or above the configured threshold."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.cpu_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_threshold_percent
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = var.instance_id
  }

  alarm_actions             = [aws_sns_topic.alerts.arn]
  ok_actions                = [aws_sns_topic.alerts.arn]
  insufficient_data_actions = []

  tags = merge(var.tags, {
    Component = "Monitoring"
    Name      = local.high_cpu_alarm_name
    Purpose   = "HighCPUAlarm"
  })
}

resource "aws_cloudwatch_metric_alarm" "status_check_failed" {
  alarm_name          = local.status_check_alarm_name
  alarm_description   = "An EC2 system or instance status check has failed."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = var.instance_id
  }

  alarm_actions             = [aws_sns_topic.alerts.arn]
  ok_actions                = [aws_sns_topic.alerts.arn]
  insufficient_data_actions = []

  tags = merge(var.tags, {
    Component = "Monitoring"
    Name      = local.status_check_alarm_name
    Purpose   = "EC2StatusAlarm"
  })
}
