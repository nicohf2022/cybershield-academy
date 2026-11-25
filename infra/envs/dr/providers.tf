provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      project   = var.project_name
      team      = var.team_name
      env       = var.environment
      owner     = var.owner
      ManagedBy = "Terraform"
    }
  }
}
