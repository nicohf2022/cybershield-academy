variable "aws_region" {
  description = "AWS region used by the regional environment."
  type        = string


  validation {
    condition     = can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]+$", var.aws_region))
    error_message = "Provide a valid AWS region."
  }
}

variable "recovery_region" {
  description = "Region B location, used to derive its backup bucket name without reading remote state."
  type        = string


  validation {
    condition     = can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]+$", var.recovery_region)) && var.recovery_region != var.aws_region
    error_message = "Use a valid AWS region different from the primary region."
  }
}

variable "recovery_backup_bucket_name" {
  description = "Existing Region B bucket name; null derives the same default as the recovery root."
  type        = string
  default     = null

  validation {
    condition = var.recovery_backup_bucket_name == null ? true : (
      length(var.recovery_backup_bucket_name) >= 3 && length(var.recovery_backup_bucket_name) <= 63 &&
      can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.recovery_backup_bucket_name))
    )
    error_message = "Use a valid 3 to 63 character bucket name with lowercase letters, numbers and hyphens."
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
    condition     = contains(["primary", "disaster-recovery"], var.environment)
    error_message = "Use primary or disaster-recovery."
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
  description = "Prefix used to name resources in the regional environment."
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
  description = "IPv4 CIDR range assigned to the regional VPC."
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
  default     = null

  validation {
    condition     = var.availability_zone == null ? true : startswith(var.availability_zone, var.aws_region)
    error_message = "The Availability Zone must belong to aws_region."
  }
}

variable "allowed_http_cidrs" {
  description = "IPv4 CIDR ranges allowed to access the application through HTTP."
  type        = set(string)
  default     = ["127.0.0.1/32"]

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
  default     = null

  validation {
    condition = (
      var.backup_bucket_name == null ? true : (length(var.backup_bucket_name) >= 3 &&
        length(var.backup_bucket_name) <= 63 &&
      can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.backup_bucket_name)))
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
  default     = 7

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

variable "enable_compute" {
  description = "Create the VM, network, workload IAM and monitoring only for an active demo."
  type        = bool
  default     = false
}
variable "enable_replication" {
  description = "Keep A-to-B data replication active independently of compute."
  type        = bool
  default     = false
  validation {
    condition     = !var.enable_replication || var.environment == "primary"
    error_message = "Only the primary region owns forward replication."
  }
}
variable "restore_manifest_uri" {
  description = "Pinned trusted S3 manifest URI to restore before app start; required for recovery compute."
  type        = string
  default     = null
  validation {
    condition     = var.restore_manifest_uri == null ? true : can(regex("^s3://[a-z0-9-]+/postgres/postgres-[0-9TZ-]+[a-f0-9]*\\.json$", var.restore_manifest_uri))
    error_message = "Use the exact project S3 postgres manifest URI without shell characters."
  }
  validation {
    condition     = !var.enable_compute || var.environment != "disaster-recovery" || var.restore_manifest_uri != null
    error_message = "Recovery compute must restore a pinned backup before starting the app."
  }
  validation {
    condition     = var.restore_manifest_uri == null ? true : contains([local.backup_bucket_name, local.recovery_backup_bucket_name], try(split("/", var.restore_manifest_uri)[2], ""))
    error_message = "Restore only from the configured regional or peer project backup bucket."
  }

}
variable "backup_retention_days" {
  description = "Expire timestamped current backups after this many days; noncurrent versions expire separately."
  type        = number
  default     = 7
  validation {
    condition     = var.backup_retention_days >= 2 && var.backup_retention_days <= 365 && floor(var.backup_retention_days) == var.backup_retention_days
    error_message = "Use 2 to 365 whole days."
  }
}

variable "workload_permissions_boundary_arn" {
  description = "Optional project workload boundary provisioned by bootstrap; CI deployments require it."
  type        = string
  default     = null
  validation {
    condition     = var.workload_permissions_boundary_arn == null ? true : can(regex("^arn:aws:iam::[0-9]{12}:policy/", var.workload_permissions_boundary_arn))
    error_message = "Provide the bootstrap workload boundary policy ARN."
  }
}

variable "precreated_instance_profile_name" {
  description = "Recovery profile created by bootstrap before disaster, avoiding IAM control-plane changes during failover."
  type        = string
  default     = null
  validation {
    condition     = var.precreated_instance_profile_name == null ? true : can(regex("^cybershield-[a-z0-9-]+$", var.precreated_instance_profile_name))
    error_message = "Use a preprovisioned project instance profile name."
  }
  validation {
    condition     = !var.enable_compute || var.environment != "disaster-recovery" || var.precreated_instance_profile_name != null
    error_message = "Recovery compute requires a bootstrap-precreated instance profile."
  }
}
