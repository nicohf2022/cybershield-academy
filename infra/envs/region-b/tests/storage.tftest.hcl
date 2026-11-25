mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
}

run "recovery_bucket_naming" {
  command = plan

  assert {
    condition     = output.backup_bucket_name == "cybershield-backups-123456789012-us-east-2"
    error_message = "Default bucket names must be unique to the account and recovery region."
  }

  assert {
    condition     = module.storage.bucket_name != "cybershield-tfstate-123456789012"
    error_message = "Database backups must use a dedicated bucket."
  }
}
