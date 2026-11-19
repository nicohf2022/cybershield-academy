variable "aws_region" {
  description = "AWS region for bootstrap API requests (IAM is global)."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]+$", var.aws_region))
    error_message = "Provide a valid AWS region name."
  }
}

variable "github_repository" {
  description = "Exact GitHub owner/repository allowed to assume the identity-only role."
  type        = string
  default     = "nicohf2022/cybershield-academy"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "Use owner/repository without wildcards."
  }
}
