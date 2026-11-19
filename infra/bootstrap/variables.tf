variable "aws_region" {
  description = "AWS region for bootstrap API requests (IAM is global)."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]+$", var.aws_region))
    error_message = "Provide a valid AWS region name."
  }
}

variable "github_oidc_subject_prefix" {
  description = "Exact repository OIDC sub_claim_prefix returned by GitHub, including immutable IDs."
  type        = string
  default     = "repo:nicohf2022@104432397/cybershield-academy@1458857174"

  validation {
    condition     = can(regex("^repo:[A-Za-z0-9_.-]+@[0-9]+/[A-Za-z0-9_.-]+@[0-9]+$", var.github_oidc_subject_prefix))
    error_message = "Use repo:OWNER@OWNER_ID/REPO@REPO_ID without wildcards."
  }
}
