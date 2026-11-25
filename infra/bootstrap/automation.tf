variable "enable_workflow_roles" {
  description = "Enable CI trust only after owner-reviewed adoption has applied workload boundaries and lowercase tags."
  type        = bool
  default     = false
  validation {
    condition     = !var.enable_workflow_roles || length(var.automation_regions) == 2
    error_message = "Configure both regional definitions before enabling workflow roles."
  }
}

variable "automation_regions" {
  description = "Opt-in CI region definitions. Configure protected GitHub environments before deploying these roles."
  type        = map(object({ region = string, name_prefix = string, state_bucket = string }))
  default     = {}
  validation {
    condition     = alltrue([for key, value in var.automation_regions : contains(["region-a", "region-b"], key) && can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]+$", value.region)) && startswith(value.name_prefix, "cybershield-") && startswith(value.state_bucket, "cybershield-tfstate-")])
    error_message = "Use region-a/region-b keys and project-owned region, name prefix and state buckets."
  }
}

resource "aws_iam_policy" "workload_boundary" {
  count       = length(var.automation_regions) == 0 ? 0 : 1
  name        = "CyberShieldWorkloadBoundary"
  description = "Maximum permissions for EC2 and S3 service roles; excludes IAM, state and infrastructure mutation."
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["s3:GetBucketLocation", "s3:ListBucket", "s3:ListBucketVersions", "s3:GetReplicationConfiguration"], Resource = "arn:aws:s3:::cybershield-backups-${data.aws_caller_identity.current.account_id}-*" },
      { Effect = "Allow", Action = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject", "s3:AbortMultipartUpload", "s3:GetObjectVersionForReplication", "s3:GetObjectVersionAcl", "s3:GetObjectVersionTagging", "s3:ReplicateObject", "s3:ReplicateTags"], Resource = "arn:aws:s3:::cybershield-backups-${data.aws_caller_identity.current.account_id}-*/postgres/*" },
      { Effect = "Allow", Action = ["logs:DescribeLogGroups"], Resource = "*" },
      { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:DescribeLogStreams", "logs:PutLogEvents"], Resource = "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:/cybershield/*:*" },
      { Effect = "Allow", Action = ["ssmmessages:CreateControlChannel", "ssmmessages:CreateDataChannel", "ssmmessages:OpenControlChannel", "ssmmessages:OpenDataChannel", "ec2messages:AcknowledgeMessage", "ec2messages:DeleteMessage", "ec2messages:FailMessage", "ec2messages:GetEndpoint", "ec2messages:GetMessages", "ec2messages:SendReply", "ssm:UpdateInstanceInformation", "ssm:ListAssociations", "ssm:DescribeAssociation", "ssm:GetDocument", "ssm:DescribeDocument", "ssm:ListInstanceAssociations", "ssm:UpdateAssociationStatus", "ssm:UpdateInstanceAssociationStatus", "ssm:PutInventory", "ssm:PutComplianceItems", "ssm:PutConfigurePackageResult"], Resource = "*" }
    ]
  })
}

locals {
  automation_roles = var.enable_workflow_roles ? merge(
    { for key, config in var.automation_regions : "plan-${key}" => merge(config, { key = key, deploy = false, environment = "plan-${key}" }) },
    { for key, config in var.automation_regions : "deploy-${key}" => merge(config, { key = key, deploy = true, environment = key }) }
  ) : {}
}

resource "aws_iam_role" "automation" {
  for_each = local.automation_roles
  name     = "CyberShield-${each.key}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Federated = aws_iam_openid_connect_provider.github.arn }, Action = "sts:AssumeRoleWithWebIdentity",
      Condition = { StringEquals = {
        "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        "token.actions.githubusercontent.com:sub" = "${var.github_oidc_subject_prefix}:environment:${each.value.environment}"
      } }
    }]
  })
  max_session_duration = 3600
}

resource "aws_iam_policy" "automation_read" {
  for_each = { for key, value in var.automation_regions : key => merge(value, { key = key }) }
  name     = "CyberShield-plan-${each.key}"
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["s3:ListBucket", "s3:GetBucketLocation"], Resource = "arn:aws:s3:::${each.value.state_bucket}" },
    { Effect = "Allow", Action = ["s3:GetObject"], Resource = "arn:aws:s3:::${each.value.state_bucket}/${each.value.key}/terraform.tfstate" },
    { Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"], Resource = "arn:aws:s3:::${each.value.state_bucket}/${each.value.key}/terraform.tfstate.tflock" },
    { Effect = "Allow", Action = ["s3:Get*", "s3:ListBucket", "s3:ListBucketVersions"], Resource = [for config in values(var.automation_regions) : "arn:aws:s3:::cybershield-backups-${data.aws_caller_identity.current.account_id}-${config.region}"] },
    { Effect = "Allow", Action = ["s3:GetObject", "s3:GetObjectVersion"], Resource = [for config in values(var.automation_regions) : "arn:aws:s3:::cybershield-backups-${data.aws_caller_identity.current.account_id}-${config.region}/postgres/*"] },
    { Effect = "Allow", Action = ["ec2:Describe*"], Resource = "*", Condition = { StringEquals = { "aws:RequestedRegion" = each.value.region } } },
    { Effect = "Allow", Action = ["iam:GetRole", "iam:GetRolePolicy", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:GetInstanceProfile"], Resource = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/cybershield-*", "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/cybershield-*"] },
    { Effect = "Allow", Action = ["iam:GetPolicy", "iam:GetPolicyVersion"], Resource = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/cybershield-*", aws_iam_policy.workload_boundary[0].arn] },
    { Effect = "Allow", Action = ["logs:DescribeLogGroups", "cloudwatch:DescribeAlarms", "sns:ListTopics"], Resource = "*", Condition = { StringEquals = { "aws:RequestedRegion" = each.value.region } } },
    { Effect = "Allow", Action = ["logs:ListTagsForResource"], Resource = "arn:aws:logs:${each.value.region}:${data.aws_caller_identity.current.account_id}:log-group:/cybershield/${each.value.name_prefix}/*" },
    { Effect = "Allow", Action = ["cloudwatch:GetDashboard"], Resource = "arn:aws:cloudwatch::${data.aws_caller_identity.current.account_id}:dashboard/cybershield-*" },
    { Effect = "Allow", Action = ["cloudwatch:ListTagsForResource"], Resource = "arn:aws:cloudwatch:${each.value.region}:${data.aws_caller_identity.current.account_id}:alarm:cybershield-*" },
    { Effect = "Allow", Action = ["sns:GetTopicAttributes", "sns:ListTagsForResource", "sns:ListSubscriptionsByTopic", "sns:GetSubscriptionAttributes"], Resource = "arn:aws:sns:${each.value.region}:${data.aws_caller_identity.current.account_id}:cybershield-*" }
  ] })
}

resource "aws_iam_role_policy" "automation_deploy" {
  for_each = { for key, value in local.automation_roles : key => value if value.deploy }
  name     = "project-deployment"
  role     = aws_iam_role.automation[each.key].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [for statement in [
    { Effect = "Allow", Action = ["s3:PutObject"], Resource = "arn:aws:s3:::${each.value.state_bucket}/${each.value.key}/terraform.tfstate" },
    { Effect = "Allow", Action = ["s3:CreateBucket", "s3:PutBucketVersioning", "s3:PutEncryptionConfiguration", "s3:PutBucketPublicAccessBlock", "s3:PutBucketOwnershipControls", "s3:PutBucketPolicy", "s3:PutBucketTagging", "s3:PutLifecycleConfiguration", "s3:PutReplicationConfiguration"], Resource = "arn:aws:s3:::cybershield-backups-${data.aws_caller_identity.current.account_id}-${each.value.region}" },
    { Effect = "Allow", Action = ["ec2:RunInstances", "ec2:CreateVpc", "ec2:CreateSubnet", "ec2:CreateInternetGateway", "ec2:CreateRouteTable", "ec2:CreateSecurityGroup"], Resource = "*", Condition = { StringEquals = { "aws:RequestedRegion" = each.value.region }, StringEqualsIfExists = { "aws:RequestTag/project" = "CyberShieldAcademy" } } },
    { Effect = "Allow", Action = ["ec2:CreateTags"], Resource = "arn:aws:ec2:${each.value.region}:${data.aws_caller_identity.current.account_id}:*/*", Condition = { StringEquals = { "ec2:CreateAction" = ["RunInstances", "CreateVpc", "CreateSubnet", "CreateInternetGateway", "CreateRouteTable", "CreateSecurityGroup", "AuthorizeSecurityGroupIngress", "AuthorizeSecurityGroupEgress"], "aws:RequestTag/project" = "CyberShieldAcademy" } } },
    { Effect = "Allow", Action = ["ec2:CreateTags"], Resource = "arn:aws:ec2:${each.value.region}:${data.aws_caller_identity.current.account_id}:*/*", Condition = { StringEquals = { "ec2:ResourceTag/project" = "CyberShieldAcademy" }, StringEqualsIfExists = { "aws:RequestTag/project" = "CyberShieldAcademy" } } },
    { Effect = "Allow", Action = ["ec2:TerminateInstances", "ec2:DeleteVpc", "ec2:DeleteSubnet", "ec2:DeleteInternetGateway", "ec2:AttachInternetGateway", "ec2:DetachInternetGateway", "ec2:ModifyVpcAttribute", "ec2:ModifySubnetAttribute", "ec2:CreateRoute", "ec2:DeleteRoute", "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable", "ec2:DeleteRouteTable", "ec2:DeleteSecurityGroup", "ec2:AuthorizeSecurityGroupIngress", "ec2:AuthorizeSecurityGroupEgress", "ec2:RevokeSecurityGroupIngress", "ec2:RevokeSecurityGroupEgress", "ec2:ModifyInstanceAttribute", "ec2:MonitorInstances", "ec2:UnmonitorInstances", "ec2:ModifyVolume"], Resource = "arn:aws:ec2:${each.value.region}:${data.aws_caller_identity.current.account_id}:*/*", Condition = { StringEquals = { "ec2:ResourceTag/project" = "CyberShieldAcademy" } } },
    { Effect = "Allow", Action = ["iam:CreateRole", "iam:PutRolePermissionsBoundary"], Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${each.value.name_prefix}-*", Condition = { ArnEquals = { "iam:PermissionsBoundary" = aws_iam_policy.workload_boundary[0].arn } } },
    { Effect = "Allow", Action = ["iam:DeleteRole", "iam:TagRole", "iam:UntagRole", "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile", "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile", "iam:TagInstanceProfile", "iam:UntagInstanceProfile"], Resource = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${each.value.name_prefix}-*", "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/${each.value.name_prefix}-*"] },
    { Effect = "Allow", Action = ["iam:CreatePolicy", "iam:DeletePolicy", "iam:CreatePolicyVersion", "iam:DeletePolicyVersion", "iam:TagPolicy", "iam:UntagPolicy"], Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${each.value.name_prefix}-*" },
    { Effect = "Allow", Action = ["iam:AttachRolePolicy", "iam:DetachRolePolicy"], Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${each.value.name_prefix}-*", Condition = { ArnLike = { "iam:PolicyARN" = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore", "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${each.value.name_prefix}-*"] } } },
    { Effect = "Allow", Action = ["iam:PassRole"], Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${each.value.name_prefix}-ec2-role", Condition = { StringEquals = { "iam:PassedToService" = "ec2.amazonaws.com" } } },
    { Effect = "Allow", Action = ["iam:PassRole"], Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${each.value.name_prefix}-s3-replication", Condition = { StringEquals = { "iam:PassedToService" = "s3.amazonaws.com" } } },
    { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:PutRetentionPolicy", "logs:TagResource", "logs:UntagResource", "logs:ListTagsForResource"], Resource = "arn:aws:logs:${each.value.region}:${data.aws_caller_identity.current.account_id}:log-group:/cybershield/${each.value.name_prefix}/*" },
    { Effect = "Allow", Action = ["cloudwatch:PutMetricAlarm", "cloudwatch:DeleteAlarms", "cloudwatch:TagResource", "cloudwatch:UntagResource"], Resource = "arn:aws:cloudwatch:${each.value.region}:${data.aws_caller_identity.current.account_id}:alarm:${each.value.name_prefix}-*" },
    { Effect = "Allow", Action = ["cloudwatch:PutDashboard", "cloudwatch:DeleteDashboards"], Resource = "arn:aws:cloudwatch::${data.aws_caller_identity.current.account_id}:dashboard/${each.value.name_prefix}-*" },
    { Effect = "Allow", Action = ["sns:CreateTopic", "sns:DeleteTopic", "sns:SetTopicAttributes", "sns:TagResource", "sns:UntagResource", "sns:Subscribe", "sns:Unsubscribe"], Resource = "arn:aws:sns:${each.value.region}:${data.aws_caller_identity.current.account_id}:${each.value.name_prefix}-*" },
    { Effect = "Allow", Action = ["ssm:SendCommand"], Resource = "arn:aws:ssm:${each.value.region}::document/AWS-RunShellScript" },
    { Effect = "Allow", Action = ["ssm:SendCommand"], Resource = "arn:aws:ec2:${each.value.region}:${data.aws_caller_identity.current.account_id}:instance/*", Condition = { StringEquals = { "ssm:resourceTag/project" = "CyberShieldAcademy" } } },
    { Effect = "Allow", Action = ["ssm:GetCommandInvocation"], Resource = "*" }
    ] : statement if each.value.key == "region-a" || !startswith(statement.Action[0], "iam:") || contains(statement.Action, "iam:PassRole")
  ] })
}

output "automation_role_arns" {
  description = "Set environment AWS_PLAN_ROLE_ARN or AWS_DEPLOY_ROLE_ARN from these reviewed roles."
  value       = { for key, role in aws_iam_role.automation : key => role.arn }
}
output "workload_boundary_arn" {
  description = "Set repository variable AWS_WORKLOAD_BOUNDARY_ARN after approved bootstrap deployment."
  value       = try(aws_iam_policy.workload_boundary[0].arn, null)
}

# Global IAM readiness is provisioned before disaster, not by the recovery state.
module "recovery_workload" {
  for_each                 = { for key, value in var.automation_regions : key => value if key == "region-b" }
  source                   = "../modules/iam"
  name_prefix              = each.value.name_prefix
  backup_bucket_arn        = "arn:aws:s3:::cybershield-backups-${data.aws_caller_identity.current.account_id}-${each.value.region}"
  log_group_arn            = "arn:aws:logs:${each.value.region}:${data.aws_caller_identity.current.account_id}:log-group:/cybershield/${each.value.name_prefix}/application:*"
  permissions_boundary_arn = aws_iam_policy.workload_boundary[0].arn
  tags                     = { project = "CyberShieldAcademy", team = "CyberShield", env = "disaster-recovery", owner = "CyberShieldTeam" }
}

output "recovery_instance_profiles" {
  description = "Set recovery regional precreated_instance_profile_name before an incident; do not read bootstrap state during failover."
  value       = { for key, workload in module.recovery_workload : key => workload.instance_profile_name }
}

resource "aws_iam_role_policy_attachment" "automation_read" {
  for_each   = local.automation_roles
  role       = aws_iam_role.automation[each.key].name
  policy_arn = aws_iam_policy.automation_read[each.value.key].arn
}
