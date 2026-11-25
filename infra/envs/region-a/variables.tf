variable "aws_region" {
  description = "AWS region used by the primary environment."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = var.aws_region == "us-east-1"
    error_message = "The primary environment must use us-east-1."
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
  default     = "primary"

  validation {
    condition     = var.environment == "primary"
    error_message = "Region A must use the primary environment."
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

variable "name_prefix" {
  description = "Prefix used to name resources in the primary environment."
  type        = string
  default     = "cybershield-primary"

  validation {
    condition = (
      length(var.name_prefix) >= 1 &&
      length(var.name_prefix) <= 48 &&
      can(regex("^[a-z0-9]+(?:-[a-z0-9]+)*$", var.name_prefix))
    )
    error_message = "The name prefix must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "vpc_cidr" {
  description = "IPv4 CIDR range assigned to the primary VPC."
  type        = string
  default     = "10.10.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "The VPC CIDR must be a valid IPv4 CIDR."
  }
}

variable "public_subnet_cidr" {
  description = "IPv4 CIDR range assigned to the public subnet."
  type        = string
  default     = "10.10.1.0/24"

  validation {
    condition     = can(cidrnetmask(var.public_subnet_cidr))
    error_message = "The public subnet CIDR must be a valid IPv4 CIDR."
  }
}

variable "availability_zone" {
  description = "Availability Zone used by the public subnet."
  type        = string
  default     = "us-east-1a"

  validation {
    condition     = can(regex("^us-east-1[a-z]$", var.availability_zone))
    error_message = "The Availability Zone must belong to us-east-1."
  }
}

variable "allowed_http_cidrs" {
  description = "IPv4 CIDR ranges allowed to access the application through HTTP."
  type        = set(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition = (
      length(var.allowed_http_cidrs) > 0 &&
      alltrue([
        for cidr in var.allowed_http_cidrs :
        can(cidrnetmask(cidr))
      ])
    )
    error_message = "Provide at least one valid IPv4 CIDR for HTTP access."
  }
}
variable "backup_bucket_name" {
  description = "Globally unique name of the S3 bucket used for PostgreSQL backups."
  type        = string
  default     = "cybershield-backups-079754672968-us-east-1"

  validation {
    condition = (
      length(var.backup_bucket_name) >= 3 &&
      length(var.backup_bucket_name) <= 63 &&
      can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.backup_bucket_name))
    )
    error_message = "The backup bucket name must contain 3 to 63 lowercase letters, numbers, or hyphens."
  }
}

variable "backup_noncurrent_version_expiration_days" {
  description = "Days before deleting noncurrent versions of backup objects."
  type        = number
  default     = 90

  validation {
    condition = (
      var.backup_noncurrent_version_expiration_days >= 30 &&
      var.backup_noncurrent_version_expiration_days <= 3650 &&
      floor(var.backup_noncurrent_version_expiration_days) == var.backup_noncurrent_version_expiration_days
    )
    error_message = "Backup noncurrent versions must be retained between 30 and 3650 whole days."
  }
}

variable "instance_type" {
  description = "EC2 instance type used for the application and PostgreSQL host."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = length(trimspace(var.instance_type)) > 0
    error_message = "The instance type cannot be empty."
  }
}

variable "root_volume_size" {
  description = "Size in GiB of the encrypted root EBS volume."
  type        = number
  default     = 12

  validation {
    condition = (
      var.root_volume_size >= 8 &&
      var.root_volume_size <= 100 &&
      floor(var.root_volume_size) == var.root_volume_size
    )
    error_message = "The root volume size must be a whole number between 8 and 100 GiB."
  }
}

variable "associate_public_ip_address" {
  description = "Whether to associate a public IPv4 address with the EC2 instance."
  type        = bool
  default     = true
}

variable "enable_detailed_monitoring" {
  description = "Whether to enable one-minute detailed monitoring for the EC2 instance."
  type        = bool
  default     = false
}

variable "notification_email_addresses" {
  description = "Email addresses subscribed to operational alerts after recipient confirmation."
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
