variable "name_prefix" {
  description = "Lowercase prefix used to identify the compute resources."
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

variable "ami_id" {
  description = "ID of the Amazon Machine Image used to launch the application instance."
  type        = string

  validation {
    condition     = can(regex("^ami-(?:[0-9a-f]{8}|[0-9a-f]{17})$", var.ami_id))
    error_message = "The AMI ID must use a valid format such as ami-0123456789abcdef0."
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

variable "subnet_id" {
  description = "ID of the subnet in which to launch the EC2 instance."
  type        = string

  validation {
    condition     = can(regex("^subnet-(?:[0-9a-f]{8}|[0-9a-f]{17})$", var.subnet_id))
    error_message = "The subnet ID must use a valid format such as subnet-0123456789abcdef0."
  }
}

variable "security_group_ids" {
  description = "IDs of the VPC Security Groups to associate with the EC2 instance."
  type        = list(string)

  validation {
    condition = (
      length(var.security_group_ids) > 0 &&
      alltrue([
        for security_group_id in var.security_group_ids :
        can(regex("^sg-(?:[0-9a-f]{8}|[0-9a-f]{17})$", security_group_id))
      ])
    )
    error_message = "Provide at least one valid Security Group ID such as sg-0123456789abcdef0."
  }
}

variable "iam_instance_profile_name" {
  description = "Name of the IAM Instance Profile to associate with the EC2 instance."
  type        = string

  validation {
    condition = (
      length(trimspace(var.iam_instance_profile_name)) > 0 &&
      length(var.iam_instance_profile_name) <= 128
    )
    error_message = "The IAM Instance Profile name must be between 1 and 128 characters."
  }
}

variable "associate_public_ip_address" {
  description = "Whether to associate a public IPv4 address with the EC2 instance."
  type        = bool
  default     = true
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

variable "root_volume_type" {
  description = "EBS volume type used for the root device."
  type        = string
  default     = "gp3"

  validation {
    condition     = var.root_volume_type == "gp3"
    error_message = "The root volume type must be gp3."
  }
}

variable "enable_detailed_monitoring" {
  description = "Whether to enable one-minute detailed monitoring for the EC2 instance."
  type        = bool
  default     = false
}

variable "user_data" {
  description = "Optional initialization script executed when the EC2 instance first launches."
  type        = string
  default     = null
  nullable    = true
}

variable "tags" {
  description = "Additional tags to apply to the EC2 instance and root EBS volume."
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

variable "user_data_base64" {
  description = "Optional base64-encoded compressed startup script; exclusive with user_data."
  type        = string
  default     = null
  validation {
    condition     = var.user_data == null || var.user_data_base64 == null
    error_message = "Provide user_data or user_data_base64, not both."
  }
}
