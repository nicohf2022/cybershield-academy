data "aws_caller_identity" "current" {}

locals {
  backup_bucket_name = coalesce(var.backup_bucket_name, "cybershield-backups-${data.aws_caller_identity.current.account_id}-${var.aws_region}")
}

# Pilot light: retain backup storage without running any recovery compute.
module "storage" {
  source = "../../modules/storage"

  bucket_name                        = local.backup_bucket_name
  force_destroy                      = false
  noncurrent_version_expiration_days = var.backup_noncurrent_version_expiration_days
}
