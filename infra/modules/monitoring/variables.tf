variable "name_prefix" {
  description = "Lowercase prefix used to identify the monitoring resources."
  type        = string

  validation {
    condition = (
      length(var.name_prefix) >= 1 &&
      length(var.name_prefix) <= 48 &&
      can(regex("^[a-z0-9]+(?:-[a-z0-9]+)*$", var.name_prefix))
    )
    error_message = "The name prefix must be 1 to 48 characters and contain only lowercase letters, numbers, and single hyphens between alphanumeric groups."
  }
}

variable "instance_id" {
  description = "ID of the EC2 instance monitored by the CloudWatch alarms."
  type        = string

  validation {
    condition     = can(regex("^i-(?:[0-9a-f]{8}|[0-9a-f]{17})$", var.instance_id))
    error_message = "The instance ID must use a valid short or long EC2 format, such as i-12345678 or i-0123456789abcdef0."
  }
}

variable "notification_email_addresses" {
  description = "Email addresses subscribed to operational alerts; AWS sends each address a confirmation message, and notifications remain inactive until the recipient confirms."
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for email_address in var.notification_email_addresses :
      can(regex("^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$", email_address))
    ])
    error_message = "Each notification address must use a valid basic email format."
  }
}

variable "log_retention_days" {
  description = "Number of days that application logs are retained in CloudWatch Logs."
  type        = number
  default     = 14

  validation {
    condition = contains([
      1,
      3,
      5,
      7,
      14,
      30,
      60,
      90,
      120,
      150,
      180,
      365,
    ], var.log_retention_days)
    error_message = "Log retention days must be one of: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, or 365."
  }
}

variable "cpu_threshold_percent" {
  description = "Average CPU utilization percentage that triggers the high CPU alarm."
  type        = number
  default     = 80

  validation {
    condition     = var.cpu_threshold_percent > 0 && var.cpu_threshold_percent <= 100
    error_message = "The CPU threshold percentage must be greater than 0 and less than or equal to 100."
  }
}

variable "cpu_evaluation_periods" {
  description = "Number of consecutive five-minute periods evaluated by the high CPU alarm."
  type        = number
  default     = 2

  validation {
    condition = (
      var.cpu_evaluation_periods >= 1 &&
      var.cpu_evaluation_periods <= 10 &&
      floor(var.cpu_evaluation_periods) == var.cpu_evaluation_periods
    )
    error_message = "CPU evaluation periods must be a whole number between 1 and 10."
  }
}

variable "tags" {
  description = "Additional tags to apply to monitoring resources that support tagging."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for key, value in var.tags :
      length(trimspace(key)) > 0 && length(trimspace(value)) > 0
    ])
    error_message = "Tag keys and values cannot be empty."
  }
}
