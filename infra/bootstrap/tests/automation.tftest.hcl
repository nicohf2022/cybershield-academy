override_resource {
  target = aws_s3_bucket.terraform_state
  values = { id = "cybershield-tfstate-123456789012" }
}
override_resource {
  target = aws_s3_bucket_versioning.terraform_state
  values = { id = "cybershield-tfstate-123456789012" }
}
override_resource {
  target = aws_s3_bucket_public_access_block.terraform_state
  values = { id = "cybershield-tfstate-123456789012" }
}
override_resource {
  target = aws_s3_bucket_server_side_encryption_configuration.terraform_state
  values = { id = "cybershield-tfstate-123456789012" }
}
mock_provider "aws" {
  mock_data "aws_iam_policy_document" { defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" } }
  mock_resource "aws_iam_policy" { defaults = { arn = "arn:aws:iam::123456789012:policy/CyberShieldWorkloadBoundary" } }
  mock_resource "aws_iam_openid_connect_provider" { defaults = { arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com" } }
  mock_data "aws_caller_identity" { defaults = { account_id = "123456789012" } }
}
mock_provider "aws" { alias = "recovery_state" }
run "iam_boundaries_and_size_limits" {
  command = apply
  variables {
    enable_workflow_roles = true
    automation_regions = {
      region-a = { region = "eu-west-1", name_prefix = "cybershield-primary", state_bucket = "cybershield-tfstate-123456789012" }
      region-b = { region = "eu-west-2", name_prefix = "cybershield-recovery", state_bucket = "cybershield-tfstate-123456789012-eu-west-2" }
    }
  }
  assert {
    condition     = alltrue([for policy in aws_iam_policy.automation_read : length(policy.policy) <= 6144]) && alltrue([for policy in aws_iam_role_policy.automation_deploy : length(policy.policy) <= 10240])
    error_message = "Generated IAM policies exceed AWS managed/inline size limits."
  }
  assert {
    condition     = jsondecode(aws_iam_role.automation["deploy-region-b"].assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"] == "repo:nicohf2022@104432397/cybershield-academy@1458857174:environment:region-b"
    error_message = "Deploy trust must be restricted to the exact immutable repository and deployment environment."
  }
  assert {
    condition     = !anytrue([for statement in jsondecode(aws_iam_role_policy.automation_deploy["deploy-region-b"].policy).Statement : contains(statement.Action, "iam:CreateRole") || contains(statement.Action, "iam:PutRolePolicy")])
    error_message = "Recovery deployment must not mutate global IAM."
  }

}
