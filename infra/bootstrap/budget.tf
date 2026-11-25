variable "budget_email_addresses" {
  description = "Team budget recipients; empty leaves the existing budget unmanaged until adoption is approved."
  type        = set(string)
  default     = []
  validation {
    condition     = alltrue([for email in var.budget_email_addresses : can(regex("^[^@ ]+@[^@ ]+\\.[^@ ]+$", email))])
    error_message = "Provide valid team email addresses."
  }
}

resource "aws_budgets_budget" "monthly" {
  count        = length(var.budget_email_addresses) == 0 ? 0 : 1
  name         = "CyberShield-Monthly-USD10"
  budget_type  = "COST"
  limit_amount = "10"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  dynamic "notification" {
    for_each = [50, 80, 100]
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = var.budget_email_addresses
    }
  }
  lifecycle { prevent_destroy = true }
}

import {
  for_each = length(var.budget_email_addresses) == 0 ? toset([]) : toset(["monthly"])
  to       = aws_budgets_budget.monthly[0]
  id       = "${data.aws_caller_identity.current.account_id}:CyberShield-Monthly-USD10"
}
