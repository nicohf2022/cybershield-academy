variable "name_prefix" {
  description = "Lowercase prefix used to name the IAM role, Instance Profile, and backup policy."
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

variable "backup_bucket_arn" {
  description = "ARN of the S3 bucket that stores PostgreSQL backups, without an object suffix."
  type        = string

  validation {
    condition     = can(regex("^arn:aws:s3:::[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.backup_bucket_arn))
    error_message = "The backup bucket ARN must use the format arn:aws:s3:::bucket-name and must not include /*."
  }
}

variable "tags" {
  description = "Additional tags to apply to IAM resources that support tagging."
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

variable "restore_bucket_arn" {
  description = "Optional trusted source bucket for failback/restore; read-only access."
  type        = string
  default     = null
  validation {
    condition     = var.restore_bucket_arn == null ? true : can(regex("^arn:aws:s3:::[a-z0-9-]+$", var.restore_bucket_arn))
    error_message = "Use a bucket ARN without an object path."
  }
}

variable "log_group_arn" {
  description = "Project log-group ARN ending in :*, used by Docker logging and the backup log collector."
  type        = string
  validation {
    condition     = can(regex("^arn:aws:logs:[^:]+:[0-9]{12}:log-group:/cybershield/.+:\\*$", var.log_group_arn))
    error_message = "Provide the regional CyberShield log-group ARN ending in :*."
  }
}

variable "permissions_boundary_arn" {
  description = "Project boundary limiting workload/service role permissions during CI deployment."
  type        = string
  default     = null
}
