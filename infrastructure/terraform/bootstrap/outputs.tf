output "state_bucket_name" {
  value = aws_s3_bucket.terraform_state.id
}

output "state_kms_key_arn" {
  value = aws_kms_key.terraform_state.arn
}

output "github_oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github_actions.arn
}

output "github_production_plan_role_arn" {
  value = aws_iam_role.github_production_plan.arn
}

output "github_production_deploy_role_arn" {
  value = aws_iam_role.github_production_deploy.arn
}
