# Initial bootstrap uses local state. Keep it private and migrate it to S3 later.
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      project = "CyberShieldAcademy"
      team    = "CyberShield"
      env     = "bootstrap"
      owner   = "CyberShieldTeam"
    }
  }
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

resource "aws_iam_role" "github_actions" {
  name        = "CyberShieldGitHubActionsRole"
  description = "Identity-only GitHub Actions OIDC test; no resource permissions."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "${var.github_oidc_subject_prefix}:ref:refs/heads/main"
        }
      }
    }]
  })
}

output "github_actions_role_arn" {
  description = "Set this as the GitHub repository variable AWS_ROLE_ARN."
  value       = aws_iam_role.github_actions.arn
}
