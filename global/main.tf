# ============================================================================
# GLOBAL — resource yang berlaku untuk seluruh account (bukan per-environment)
# Saat ini: guardrail biaya (AWS Budgets). Bisa ditambah IAM, Route53, dll.
# ============================================================================

terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" # Budgets bersifat global; us-east-1 adalah konvensi
  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "Terraform"
      Component = "global"
    }
  }
}

# --- Monthly budget and alerts ---------------------------------------------
#
# Scoped by tag, not account-wide. This account carries workloads that predate
# this repository and cost far more than this budget; an unfiltered budget would
# breach on day one and every alert after that would be noise.
#
# Requires the `Project` cost allocation tag to be activated once in
# Billing -> Cost allocation tags. Until then the budget reports zero spend.
resource "aws_budgets_budget" "monthly" {
  name         = "${var.project}-monthly-budget"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  dynamic "cost_filter" {
    for_each = var.budget_tag_filter != null ? [1] : []

    content {
      name = "TagKeyValue"
      # format() avoids the $-escaping ambiguity of an interpolated string here.
      values = [format("user:Project$%s", var.budget_tag_filter)]
    }
  }

  # Peringatan saat biaya AKTUAL melewati 80% dari budget
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
  }

  # Peringatan saat biaya DIPERKIRAKAN (forecast) melewati 100% budget
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.alert_emails
  }
}
