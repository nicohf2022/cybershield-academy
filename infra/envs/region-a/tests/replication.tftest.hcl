mock_provider "aws" {}

run "prefix_scoped_one_way_replication" {
  command = plan

  module {
    source = "../../modules/replication"
  }

  variables {
    name_prefix            = "cybershield-test"
    source_bucket_name     = "cybershield-test-source"
    destination_bucket_arn = "arn:aws:s3:::cybershield-test-recovery"
  }

  assert {
    condition     = one(aws_s3_bucket_replication_configuration.backups.rule).filter[0].prefix == "postgres/"
    error_message = "Only database backup objects should be replicated."
  }

  assert {
    condition     = one(aws_s3_bucket_replication_configuration.backups.rule).delete_marker_replication[0].status == "Disabled"
    error_message = "Source deletion must not hide recovery backups."
  }

  assert {
    condition     = one(aws_s3_bucket_replication_configuration.backups.rule).destination[0].bucket == var.destination_bucket_arn
    error_message = "Backups must target the configured recovery bucket."
  }

  assert {
    condition = (
      jsondecode(aws_iam_role_policy.replication.policy).Statement[1].Resource == "arn:aws:s3:::cybershield-test-source/postgres/*" &&
      jsondecode(aws_iam_role_policy.replication.policy).Statement[2].Resource == "arn:aws:s3:::cybershield-test-recovery/postgres/*" &&
      !contains(jsondecode(aws_iam_role_policy.replication.policy).Statement[2].Action, "s3:ReplicateDelete")
    )
    error_message = "Replication access must stay within the backup prefixes without deletion permissions."
  }
}

run "reject_same_source_and_destination" {
  command = plan

  module {
    source = "../../modules/replication"
  }

  variables {
    name_prefix            = "cybershield-test"
    source_bucket_name     = "cybershield-test-source"
    destination_bucket_arn = "arn:aws:s3:::cybershield-test-source"
  }

  expect_failures = [var.destination_bucket_arn]
}

run "reject_wildcard_prefix" {
  command = plan

  module {
    source = "../../modules/replication"
  }

  variables {
    name_prefix            = "cybershield-test"
    source_bucket_name     = "cybershield-test-source"
    destination_bucket_arn = "arn:aws:s3:::cybershield-test-recovery"
    object_prefix          = "*"
  }

  expect_failures = [var.object_prefix]
}
