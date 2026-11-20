# Existing bucket and settings discovered in AWS. Imports are recorded on apply.
# These blocks can remain after adoption; Terraform skips completed imports.
import {
  to = aws_s3_bucket.terraform_state
  id = "cybershield-tfstate-${data.aws_caller_identity.current.account_id}"
}

import {
  to = aws_s3_bucket_versioning.terraform_state
  id = "cybershield-tfstate-${data.aws_caller_identity.current.account_id}"
}

import {
  to = aws_s3_bucket_public_access_block.terraform_state
  id = "cybershield-tfstate-${data.aws_caller_identity.current.account_id}"
}

import {
  to = aws_s3_bucket_server_side_encryption_configuration.terraform_state
  id = "cybershield-tfstate-${data.aws_caller_identity.current.account_id}"
}
