locals {
  log_group_name          = "/cybershield/${var.name_prefix}/application"
  sns_topic_name          = "${var.name_prefix}-alerts"
  high_cpu_alarm_name     = "${var.name_prefix}-high-cpu"
  status_check_alarm_name = "${var.name_prefix}-status-check-failed"
}

data "aws_region" "current" {}

resource "aws_cloudwatch_dashboard" "application" {
  dashboard_name = "${var.name_prefix}-overview"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title   = "EC2 CPU utilization", region = data.aws_region.current.region
          metrics = [["AWS/EC2", "CPUUtilization", "InstanceId", var.instance_id]]
          period  = 300, stat = "Average"
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title   = "EC2 status checks", region = data.aws_region.current.region
          metrics = [["AWS/EC2", "StatusCheckFailed", "InstanceId", var.instance_id]]
          period  = 60, stat = "Maximum"
        }
      },
      {
        type = "log", x = 0, y = 6, width = 24, height = 6
        properties = {
          title = "Application errors and backup results", region = data.aws_region.current.region
          query = "SOURCE '${local.log_group_name}' | fields @timestamp, @logStream, @message | filter @message like /ERROR|error|backup_uploaded|operation_failed/ | sort @timestamp desc | limit 50"
          view  = "table"
        }
      }
    ]
  })
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

# Non-sensitive operational metadata only; see docs/security.md for KMS tradeoff.
#trivy:ignore:AWS-0095
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
