variable "aws_region" {
  description = "AWS region used by the disaster recovery environment."
  type        = string
  default     = "us-east-2"

  validation {
    condition     = var.aws_region == "us-east-2"
    error_message = "The disaster recovery environment must use us-east-2."
  }
}

variable "project_name" {
  description = "Project name used in resource tags."
  type        = string
  default     = "CyberShieldAcademy"

  validation {
    condition     = length(trimspace(var.project_name)) > 0
    error_message = "The project name cannot be empty."
  }
}

variable "team_name" {
  description = "Team responsible for the resources."
  type        = string
  default     = "CyberShield"

  validation {
    condition     = length(trimspace(var.team_name)) > 0
    error_message = "The team name cannot be empty."
  }
}

variable "environment" {
  description = "Environment represented by this Terraform root module."
  type        = string
  default     = "disaster-recovery"

  validation {
    condition     = var.environment == "disaster-recovery"
    error_message = "Region B must use the disaster-recovery environment."
  }
}

variable "owner" {
  description = "Owner used to identify the team responsible for the resources."
  type        = string
  default     = "CyberShieldTeam"

  validation {
    condition     = length(trimspace(var.owner)) > 0
    error_message = "The owner cannot be empty."
  }
}