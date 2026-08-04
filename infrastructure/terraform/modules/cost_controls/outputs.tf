output "monthly_budget_name" {
  value = aws_budgets_budget.monthly.name
}

output "operations_topic_arn" {
  value = aws_sns_topic.operations.arn
}

output "operating_mode_parameter_name" {
  value = aws_ssm_parameter.operating_mode.name
}

output "governor_function_arn" {
  value = aws_lambda_function.governor.arn
}
