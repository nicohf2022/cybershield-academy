variable "name_prefix" {
  description = "Lowercase prefix used to identify the network resources."
  type        = string

  validation {
    condition = (
      length(var.name_prefix) >= 1 &&
      length(var.name_prefix) <= 63 &&
      can(regex("^[a-z0-9]+(?:-[a-z0-9]+)*$", var.name_prefix))
    )
    error_message = "The name prefix must be 1 to 63 characters and contain only lowercase letters, numbers, and single hyphens between alphanumeric groups."
  }
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block assigned to the VPC."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && !strcontains(var.vpc_cidr, ":")
    error_message = "The VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_cidr" {
  description = "IPv4 CIDR block assigned to the public subnet."
  type        = string

  validation {
    condition     = can(cidrhost(var.public_subnet_cidr, 0)) && !strcontains(var.public_subnet_cidr, ":")
    error_message = "The public subnet CIDR must be a valid IPv4 CIDR block."
  }
}

variable "availability_zone" {
  description = "Availability Zone in which to create the public subnet."
  type        = string

  validation {
    condition     = length(trimspace(var.availability_zone)) > 0
    error_message = "The Availability Zone cannot be empty."
  }
}

variable "allowed_http_cidrs" {
  description = "IPv4 CIDR blocks allowed to reach the application over TCP port 80."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition = (
      length(var.allowed_http_cidrs) > 0 &&
      alltrue([
        for cidr in var.allowed_http_cidrs :
        can(cidrhost(cidr, 0)) && !strcontains(cidr, ":")
      ])
    )
    error_message = "At least one valid IPv4 CIDR block must be supplied for HTTP access."
  }
}

variable "tags" {
  description = "Additional tags to apply to resources that support tagging."
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
