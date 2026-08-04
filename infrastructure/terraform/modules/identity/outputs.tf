output "user_pool_id" {
  value = aws_cognito_user_pool.this.id
}

output "user_pool_arn" {
  value = aws_cognito_user_pool.this.arn
}

output "android_client_id" {
  value = aws_cognito_user_pool_client.android.id
}

output "issuer" {
  value = "https://cognito-idp.${data.aws_region.current.region}.${data.aws_partition.current.dns_suffix}/${aws_cognito_user_pool.this.id}"
}

output "jwk_set_uri" {
  value = "https://cognito-idp.${data.aws_region.current.region}.${data.aws_partition.current.dns_suffix}/${aws_cognito_user_pool.this.id}/.well-known/jwks.json"
}

output "authorization_base_url" {
  value = "https://${aws_cognito_user_pool_domain.this.domain}.auth.${data.aws_region.current.region}.amazoncognito.com"
}

output "google_oidc_secret_arn" {
  value = aws_secretsmanager_secret.google_oidc.arn
}
