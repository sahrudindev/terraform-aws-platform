output "github_actions_plan_role_arn" {
  description = "Set as the AWS_PLAN_ROLE_ARN repository variable in GitHub"
  value       = aws_iam_role.plan.arn
}

output "github_actions_apply_role_arn" {
  description = "Set as the AWS_APPLY_ROLE_ARN repository variable in GitHub"
  value       = aws_iam_role.apply.arn
}

output "github_oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}

output "budget_name" {
  value = aws_budgets_budget.monthly.name
}
