variable "aws_region" {
  description = "AWS region used by the disaster recovery environment."
  type        = string
  default     = "us-east-2"

  validation {
    condition     = var.aws_region == "us-east-2"
    error_message = "The disaster recovery environment must use us-east-2."
  }
}

variable "project_name" {
  description = "Project name used in resource tags."
  type        = string
  default     = "CyberShieldAcademy"

  validation {
    condition     = length(trimspace(var.project_name)) > 0
    error_message = "The project name cannot be empty."
  }
}

variable "team_name" {
  description = "Team responsible for the resources."
  type        = string
  default     = "CyberShield"

  validation {
    condition     = length(trimspace(var.team_name)) > 0
    error_message = "The team name cannot be empty."
  }
}

variable "environment" {
  description = "Environment represented by this Terraform root module."
  type        = string
  default     = "disaster-recovery"

  validation {
    condition     = var.environment == "disaster-recovery"
    error_message = "Region B must use the disaster-recovery environment."
  }
}

variable "owner" {
  description = "Owner used to identify the team responsible for the resources."
  type        = string
  default     = "CyberShieldTeam"

  validation {
    condition     = length(trimspace(var.owner)) > 0
    error_message = "The owner cannot be empty."
  }
}

variable "backup_bucket_name" {
  description = "Optional recovery bucket name; null derives an account- and region-specific name."
  type        = string
  default     = null

  validation {
    condition = var.backup_bucket_name == null ? true : (
      length(var.backup_bucket_name) >= 3 && length(var.backup_bucket_name) <= 63 &&
      can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.backup_bucket_name))
    )
    error_message = "Use a valid 3 to 63 character bucket name with lowercase letters, numbers and hyphens."
  }
}

variable "backup_noncurrent_version_expiration_days" {
  description = "Days to retain noncurrent recovery object versions; current backups are retained."
  type        = number
  default     = 90

  validation {
    condition = (
      var.backup_noncurrent_version_expiration_days >= 30 &&
      var.backup_noncurrent_version_expiration_days <= 3650 &&
      floor(var.backup_noncurrent_version_expiration_days) == var.backup_noncurrent_version_expiration_days
    )
    error_message = "Use a whole number of days between 30 and 3650."
  }
}
