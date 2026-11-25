variable "recovery_state_region" {
  description = "Optional region for an independently available DR state bucket; enable only after review."
  type        = string
  default     = null
  validation {
    condition     = var.recovery_state_region == null ? true : (can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]+$", var.recovery_state_region)) && var.recovery_state_region != var.aws_region)
    error_message = "Use a different valid region for recovery state."
  }
}

provider "aws" {
  alias  = "recovery_state"
  region = coalesce(var.recovery_state_region, var.aws_region)
  default_tags {
    tags = { project = "CyberShieldAcademy", team = "CyberShield", env = "shared", owner = "CyberShieldTeam" }
  }
}

resource "aws_s3_bucket" "recovery_state" {
  count         = var.recovery_state_region == null ? 0 : 1
  provider      = aws.recovery_state
  bucket        = "cybershield-tfstate-${data.aws_caller_identity.current.account_id}-${var.recovery_state_region}"
  force_destroy = false
  lifecycle { prevent_destroy = true }
}

resource "aws_s3_bucket_versioning" "recovery_state" {
  count    = var.recovery_state_region == null ? 0 : 1
  provider = aws.recovery_state
  bucket   = aws_s3_bucket.recovery_state[0].id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_public_access_block" "recovery_state" {
  count                   = var.recovery_state_region == null ? 0 : 1
  provider                = aws.recovery_state
  bucket                  = aws_s3_bucket.recovery_state[0].id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# SSE-S3 AES256 is deliberate for this low-cost demo; see docs/security.md.
#trivy:ignore:AWS-0132
resource "aws_s3_bucket_server_side_encryption_configuration" "recovery_state" {
  count    = var.recovery_state_region == null ? 0 : 1
  provider = aws.recovery_state
  bucket   = aws_s3_bucket.recovery_state[0].id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_policy" "recovery_state_tls" {
  count    = var.recovery_state_region == null ? 0 : 1
  provider = aws.recovery_state
  bucket   = aws_s3_bucket.recovery_state[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Deny", Principal = "*", Action = "s3:*",
      Resource  = [aws_s3_bucket.recovery_state[0].arn, "${aws_s3_bucket.recovery_state[0].arn}/*"],
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
}

output "recovery_state_bucket" {
  description = "Proposed destination for an explicitly approved Region B state migration."
  value       = try(aws_s3_bucket.recovery_state[0].id, null)
}
