mock_provider "aws" {
  mock_data "aws_iam_policy_document" { defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" } }
  mock_data "aws_caller_identity" { defaults = { account_id = "123456789012" } }
  mock_data "aws_ami" { defaults = { id = "ami-0123456789abcdef0" } }
  mock_data "aws_availability_zones" { defaults = { names = ["eu-west-1a"] } }
}
variables {
  aws_region                       = "eu-west-1"
  recovery_region                  = "eu-west-2"
  precreated_instance_profile_name = "cybershield-test-ec2-profile"
}
run "storage_only_pilot_light" {
  command = plan
  variables { environment = "disaster-recovery" }
  assert {
    condition     = output.instance_id == null && output.application_url == null
    error_message = "Pilot light must have no running VM."
  }
  assert {
    condition     = output.backup_bucket_name == "cybershield-backups-123456789012-eu-west-1"
    error_message = "Bucket naming must derive from the selected region and account."
  }
}
run "recovery_requires_manifest" {
  command = plan
  variables {
    environment    = "disaster-recovery"
    enable_compute = true
  }
  expect_failures = [var.restore_manifest_uri]
}
run "arbitrary_region_recovery" {
  command = plan
  variables {
    environment          = "disaster-recovery"
    name_prefix          = "cybershield-recovery"
    enable_compute       = true
    restore_manifest_uri = "s3://cybershield-backups-123456789012-eu-west-1/postgres/postgres-20261125T000000000000Z-12345678.json"
  }
  assert {
    condition     = length(module.iam) == 0
    error_message = "Failover must use its preprovisioned profile without managing global IAM resources."
  }
}

run "recovery_requires_preprovisioned_iam" {
  command = plan
  variables {
    environment                      = "disaster-recovery"
    enable_compute                   = true
    precreated_instance_profile_name = null
    restore_manifest_uri             = "s3://cybershield-backups-123456789012-eu-west-1/postgres/postgres-20261125T000000000000Z-12345678.json"
  }
  expect_failures = [var.precreated_instance_profile_name]
}
