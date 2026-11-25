variable "name_prefix" {
  description = "Prefix for the S3 replication role and inline policy."
  type        = string

  validation {
    condition     = length(var.name_prefix) <= 48 && can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", var.name_prefix))
    error_message = "Use 1 to 48 lowercase letters, numbers or hyphens between groups."
  }
}

variable "source_bucket_name" {
  description = "Existing versioned source bucket in the current provider region."
  type        = string

  validation {
    condition     = length(var.source_bucket_name) >= 3 && length(var.source_bucket_name) <= 63 && can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.source_bucket_name))
    error_message = "Use a valid 3 to 63 character bucket name with lowercase letters, numbers and hyphens."
  }
}

variable "destination_bucket_arn" {
  description = "ARN of the existing versioned destination bucket in the same AWS account."
  type        = string

  validation {
    condition     = can(regex("^arn:aws:s3:::[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.destination_bucket_arn))
    error_message = "Use a commercial AWS bucket ARN without an object path."
  }

  validation {
    condition     = var.destination_bucket_arn != "arn:aws:s3:::${var.source_bucket_name}"
    error_message = "Replication source and destination must be different buckets."
  }
}

variable "object_prefix" {
  description = "Nonempty object prefix to replicate, including its trailing slash."
  type        = string
  default     = "postgres/"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9/_-]*/$", var.object_prefix)) && !strcontains(var.object_prefix, "//")
    error_message = "Use a nonempty lowercase path ending in /, without wildcards or empty segments."
  }
}

variable "tags" {
  description = "Ownership tags for the S3 replication role."
  type        = map(string)
  default     = {}
}

variable "permissions_boundary_arn" {
  description = "Project boundary limiting workload/service role permissions during CI deployment."
  type        = string
  default     = null
}
