data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

data "archive_file" "account_linker" {
  type             = "zip"
  source_file      = "${path.module}/lambda/account_linker.py"
  output_path      = "${path.module}/account-linker.zip"
  output_file_mode = "0666"
}

data "archive_file" "google_configurator" {
  type             = "zip"
  source_file      = "${path.module}/lambda/google_configurator.py"
  output_path      = "${path.module}/google-configurator.zip"
  output_file_mode = "0666"
}

resource "aws_cloudwatch_log_group" "account_linker" {
  name              = "/kelimio/${var.environment}/identity-linker"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "google_configurator" {
  name              = "/kelimio/${var.environment}/google-identity-configurator"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}

resource "aws_iam_role" "account_linker" {
  name = "${var.name_prefix}-identity-linker"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
  tags = var.tags
}

data "aws_iam_policy_document" "account_linker" {
  statement {
    sid = "ManageVerifiedLinksInTaggedPool"
    actions = [
      "cognito-idp:AdminCreateUser",
      "cognito-idp:AdminLinkProviderForUser",
      "cognito-idp:AdminSetUserPassword",
      "cognito-idp:ListUsers"
    ]
    resources = ["arn:${data.aws_partition.current.partition}:cognito-idp:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:userpool/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"
      values   = ["kelimio"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Environment"
      values   = [var.environment]
    }
  }

  statement {
    sid       = "WriteOwnLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/kelimio/${var.environment}/identity-linker:*"]
  }
}

resource "aws_iam_role_policy" "account_linker" {
  name   = "${var.name_prefix}-identity-linker"
  role   = aws_iam_role.account_linker.id
  policy = data.aws_iam_policy_document.account_linker.json
}

resource "aws_lambda_function" "account_linker" {
  function_name    = "${var.name_prefix}-identity-linker"
  role             = aws_iam_role.account_linker.arn
  handler          = "account_linker.handler"
  runtime          = "python3.13"
  filename         = data.archive_file.account_linker.output_path
  source_code_hash = data.archive_file.account_linker.output_base64sha256
  timeout          = 15
  memory_size      = 128

  depends_on = [
    aws_cloudwatch_log_group.account_linker,
    aws_iam_role_policy.account_linker
  ]

  tags = var.tags
}

resource "aws_lambda_permission" "cognito_account_linker" {
  statement_id   = "AllowCognitoPreSignUp"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.account_linker.function_name
  principal      = "cognito-idp.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}

resource "aws_cognito_user_pool" "this" {
  name                = "${var.name_prefix}-users"
  deletion_protection = "ACTIVE"
  user_pool_tier      = "ESSENTIALS"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]
  mfa_configuration        = "OPTIONAL"

  username_configuration {
    case_sensitive = false
  }

  sign_in_policy {
    allowed_first_auth_factors = ["PASSWORD"]
  }

  password_policy {
    minimum_length                   = 12
    password_history_size            = 5
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 3
  }

  software_token_mfa_configuration {
    enabled = true
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  user_attribute_update_settings {
    attributes_require_verification_before_update = ["email"]
  }

  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
  }

  schema {
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = false
    name                     = "canonical_origin"
    required                 = false

    string_attribute_constraints {
      min_length = 1
      max_length = 32
    }
  }

  lambda_config {
    pre_sign_up = aws_lambda_function.account_linker.arn
  }

  tags = var.tags

  depends_on = [aws_lambda_permission.cognito_account_linker]
}

resource "aws_secretsmanager_secret" "google_oidc" {
  name                    = "${var.name_prefix}/google-oidc"
  description             = "Owner-supplied Google OIDC clientId/clientSecret JSON; Terraform never manages the secret value."
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 30
  tags                    = merge(var.tags, { DataClass = "identity-provider-secret" })
}

resource "aws_iam_role" "google_configurator" {
  name = "${var.name_prefix}-google-identity-configurator"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
  tags = var.tags
}

data "aws_iam_policy_document" "google_configurator" {
  statement {
    sid       = "ReadOnlyGoogleSecret"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.google_oidc.arn]
  }

  statement {
    sid       = "DecryptOnlyGoogleSecret"
    actions   = ["kms:Decrypt"]
    resources = [var.kms_key_arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${data.aws_region.current.region}.${data.aws_partition.current.dns_suffix}"]
    }
  }

  statement {
    sid = "ManageGoogleProviderInTaggedPool"
    actions = [
      "cognito-idp:CreateIdentityProvider",
      "cognito-idp:DeleteIdentityProvider",
      "cognito-idp:DescribeIdentityProvider",
      "cognito-idp:UpdateIdentityProvider"
    ]
    resources = [aws_cognito_user_pool.this.arn]
  }

  statement {
    sid       = "WriteOwnLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/kelimio/${var.environment}/google-identity-configurator:*"]
  }
}

resource "aws_iam_role_policy" "google_configurator" {
  name   = "${var.name_prefix}-google-identity-configurator"
  role   = aws_iam_role.google_configurator.id
  policy = data.aws_iam_policy_document.google_configurator.json
}

resource "aws_lambda_function" "google_configurator" {
  function_name    = "${var.name_prefix}-google-identity-configurator"
  role             = aws_iam_role.google_configurator.arn
  handler          = "google_configurator.handler"
  runtime          = "python3.13"
  filename         = data.archive_file.google_configurator.output_path
  source_code_hash = data.archive_file.google_configurator.output_base64sha256
  timeout          = 30
  memory_size      = 128

  depends_on = [
    aws_cloudwatch_log_group.google_configurator,
    aws_iam_role_policy.google_configurator
  ]

  tags = var.tags
}

resource "aws_lambda_invocation" "google_identity" {
  count = var.google_identity_enabled ? 1 : 0

  function_name   = aws_lambda_function.google_configurator.function_name
  lifecycle_scope = "CRUD"
  input = jsonencode({
    userPoolId = aws_cognito_user_pool.this.id
    secretArn  = aws_secretsmanager_secret.google_oidc.arn
  })
  triggers = {
    code_hash             = data.archive_file.google_configurator.output_base64sha256
    configuration_version = var.google_identity_configuration_version
  }
}

resource "aws_cognito_user_pool_client" "android" {
  name         = "${var.name_prefix}-android"
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret                      = false
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  callback_urls                        = var.callback_urls
  logout_urls                          = var.logout_urls
  supported_identity_providers         = var.google_identity_enabled ? ["COGNITO", "Google"] : ["COGNITO"]
  prevent_user_existence_errors        = "ENABLED"
  enable_token_revocation              = true
  explicit_auth_flows                  = ["ALLOW_USER_SRP_AUTH"]
  access_token_validity                = 15
  id_token_validity                    = 15
  refresh_token_validity               = 30
  auth_session_validity                = 3

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  refresh_token_rotation {
    feature                    = "ENABLED"
    retry_grace_period_seconds = 10
  }

  read_attributes = [
    "email",
    "email_verified",
    "family_name",
    "given_name",
    "name"
  ]
  write_attributes = [
    "email",
    "family_name",
    "given_name",
    "name"
  ]

  depends_on = [aws_lambda_invocation.google_identity]
}

resource "aws_cognito_user_pool_domain" "this" {
  domain                = var.domain_prefix
  user_pool_id          = aws_cognito_user_pool.this.id
  managed_login_version = 2
}
