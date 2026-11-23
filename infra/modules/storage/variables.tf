variable "bucket_name" {
  description = "Globally unique name of the S3 bucket used to store PostgreSQL backups."
  type        = string

  validation {
    condition = (
      length(var.bucket_name) >= 3 &&
      length(var.bucket_name) <= 63 &&
      can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.bucket_name)) &&
      !strcontains(var.bucket_name, "..") &&
      !can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}$", var.bucket_name))
    )
    error_message = "The bucket name must be 3 to 63 characters, use only lowercase letters, numbers, periods, or hyphens, begin and end with a letter or number, contain no adjacent periods, and not use IPv4 address format."
  }
}

variable "force_destroy" {
  description = "Whether Terraform may delete the bucket when it still contains backup objects or versions."
  type        = bool
  default     = false
}

variable "noncurrent_version_expiration_days" {
  description = "Number of days after which noncurrent backup versions expire; null disables expiration."
  type        = number
  default     = null
  nullable    = true

  validation {
    condition = var.noncurrent_version_expiration_days == null ? true : (
      var.noncurrent_version_expiration_days >= 30 &&
      var.noncurrent_version_expiration_days <= 3650 &&
      floor(var.noncurrent_version_expiration_days) == var.noncurrent_version_expiration_days
    )
    error_message = "Noncurrent version expiration days must be null or a whole number between 30 and 3650."
  }
}

variable "tags" {
  description = "Additional tags to apply to the backup bucket."
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
