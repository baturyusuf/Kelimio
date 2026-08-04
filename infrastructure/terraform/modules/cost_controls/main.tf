data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  control_modes = {
    conserve  = "CONSERVE"
    read_only = "READ_ONLY"
    suspend   = "SUSPENDED"
  }
  budget_topics = merge(
    { operations = aws_sns_topic.operations.arn },
    { for name, topic in aws_sns_topic.control : name => topic.arn }
  )
}

resource "aws_ssm_parameter" "operating_mode" {
  name        = var.operating_mode_parameter_name
  description = "Server-authoritative Kelimio production cost operating mode"
  type        = "String"
  value       = "NORMAL"
  tags        = var.tags

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_dynamodb_table" "governor_lock" {
  name         = "${var.name_prefix}-cost-governor-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "lock_name"

  attribute {
    name = "lock_name"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  tags = merge(var.tags, { DataClass = "ephemeral-control-lock" })
}

resource "aws_sns_topic" "operations" {
  name              = "${var.name_prefix}-cost-operations"
  display_name      = "Kelimio production cost controls"
  signature_version = 2
  kms_master_key_id = var.kms_key_arn
  tags              = var.tags
}

resource "aws_sns_topic" "control" {
  for_each = local.control_modes

  name              = "${var.name_prefix}-cost-${each.key}"
  signature_version = 2
  kms_master_key_id = var.kms_key_arn
  tags              = var.tags
}

resource "aws_sns_topic_subscription" "operations_email" {
  topic_arn = aws_sns_topic.operations.arn
  protocol  = "email"
  endpoint  = var.budget_notification_email
}

data "aws_iam_policy_document" "budget_topic" {
  for_each = local.budget_topics

  statement {
    sid = "OwnerControl"
    actions = [
      "sns:AddPermission",
      "sns:DeleteTopic",
      "sns:GetDataProtectionPolicy",
      "sns:GetTopicAttributes",
      "sns:ListSubscriptionsByTopic",
      "sns:ListTagsForResource",
      "sns:Publish",
      "sns:PutDataProtectionPolicy",
      "sns:RemovePermission",
      "sns:SetTopicAttributes",
      "sns:Subscribe"
    ]
    resources = [each.value]

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid       = "AllowAwsBudgetsPublish"
    actions   = ["sns:Publish"]
    resources = [each.value]

    principals {
      type        = "Service"
      identifiers = ["budgets.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  dynamic "statement" {
    for_each = each.key == "operations" ? [1] : []

    content {
      sid       = "AllowProductionAlarmsPublish"
      actions   = ["sns:Publish"]
      resources = [each.value]

      principals {
        type        = "Service"
        identifiers = ["cloudwatch.amazonaws.com"]
      }

      condition {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [data.aws_caller_identity.current.account_id]
      }

      condition {
        test     = "ArnLike"
        variable = "aws:SourceArn"
        values   = ["arn:${data.aws_partition.current.partition}:cloudwatch:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:alarm:${var.name_prefix}-*"]
      }
    }
  }
}

resource "aws_sns_topic_policy" "operations" {
  arn    = aws_sns_topic.operations.arn
  policy = data.aws_iam_policy_document.budget_topic["operations"].json
}

resource "aws_sns_topic_policy" "control" {
  for_each = aws_sns_topic.control

  arn    = each.value.arn
  policy = data.aws_iam_policy_document.budget_topic[each.key].json
}

data "archive_file" "governor" {
  type             = "zip"
  source_file      = "${path.module}/lambda/handler.py"
  output_path      = "${path.module}/cost-governor.zip"
  output_file_mode = "0666"
}

resource "aws_iam_role" "governor" {
  name = "${var.name_prefix}-cost-governor"
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

data "aws_iam_policy_document" "governor" {
  statement {
    sid       = "SerializeCostControl"
    actions   = ["dynamodb:DeleteItem", "dynamodb:PutItem"]
    resources = [aws_dynamodb_table.governor_lock.arn]
  }

  statement {
    sid = "UseCostControlLockKey"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey*"
    ]
    resources = [var.kms_key_arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["dynamodb.${data.aws_region.current.region}.${data.aws_partition.current.dns_suffix}"]
    }
  }

  statement {
    sid       = "WriteOperatingMode"
    actions   = ["ssm:GetParameter", "ssm:PutParameter"]
    resources = [aws_ssm_parameter.operating_mode.arn]
  }

  statement {
    sid       = "DescribeSuspendibleCompute"
    actions   = ["ec2:DescribeInstances", "ecs:DescribeServices", "rds:DescribeDBInstances"]
    resources = ["*"]
  }

  statement {
    sid       = "StopTaggedEcsServices"
    actions   = ["ecs:UpdateService"]
    resources = [for item in var.suspendible_ecs_services : "arn:${data.aws_partition.current.partition}:ecs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:service/${item.cluster}/${item.service}"]

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

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/AutoSuspend"
      values   = ["true"]
    }
  }

  statement {
    sid       = "StopTaggedEc2"
    actions   = ["ec2:StopInstances"]
    resources = ["arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:instance/*"]

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

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/AutoSuspend"
      values   = ["true"]
    }
  }

  statement {
    sid       = "StopTaggedRds"
    actions   = ["rds:StopDBInstance"]
    resources = ["arn:${data.aws_partition.current.partition}:rds:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:db:*"]

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

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/AutoSuspend"
      values   = ["true"]
    }
  }

  statement {
    sid       = "WriteOwnLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/kelimio/${var.environment}/cost-governor:*:*"]
  }
}

resource "aws_iam_role_policy" "governor" {
  name   = "${var.name_prefix}-cost-governor"
  role   = aws_iam_role.governor.id
  policy = data.aws_iam_policy_document.governor.json
}

resource "aws_cloudwatch_log_group" "governor" {
  name              = "/kelimio/${var.environment}/cost-governor"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_lambda_function" "governor" {
  function_name    = "${var.name_prefix}-cost-governor"
  role             = aws_iam_role.governor.arn
  handler          = "handler.handler"
  runtime          = "python3.13"
  filename         = data.archive_file.governor.output_path
  source_code_hash = data.archive_file.governor.output_base64sha256
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      CONTROL_TOPIC_MODES      = jsonencode({ for name, topic in aws_sns_topic.control : topic.arn => local.control_modes[name] })
      GOVERNOR_LOCK_TABLE      = aws_dynamodb_table.governor_lock.name
      OPERATING_MODE_PARAMETER = aws_ssm_parameter.operating_mode.name
      EC2_INSTANCE_IDS         = jsonencode(var.suspendible_ec2_instance_ids)
      ECS_SERVICES             = jsonencode(var.suspendible_ecs_services)
      RDS_INSTANCE_IDENTIFIERS = jsonencode(var.suspendible_rds_instance_identifiers)
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.governor,
    aws_iam_role_policy.governor
  ]

  tags = var.tags
}

resource "aws_cloudwatch_event_rule" "suspension_recheck" {
  name                = "${var.name_prefix}-suspension-recheck"
  description         = "Reasserts suspended compute state after provider auto-restarts"
  schedule_expression = "rate(6 hours)"
  tags                = var.tags
}

resource "aws_lambda_permission" "events" {
  statement_id  = "AllowScheduledSuspensionRecheck"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.governor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.suspension_recheck.arn
}

resource "aws_cloudwatch_event_target" "suspension_recheck" {
  rule      = aws_cloudwatch_event_rule.suspension_recheck.name
  target_id = "cost-governor"
  arn       = aws_lambda_function.governor.arn
  input     = jsonencode({ source = "aws.events", action = "reassert-suspension" })

  depends_on = [aws_lambda_permission.events]
}

resource "aws_cloudwatch_event_rule" "monthly_reset" {
  name                = "${var.name_prefix}-cost-monthly-reset"
  description         = "Returns the application mode to normal at the start of a new AWS budget month; stopped compute stays stopped"
  schedule_expression = "cron(15 1 1 * ? *)"
  tags                = var.tags
}

resource "aws_lambda_permission" "monthly_reset" {
  statement_id  = "AllowMonthlyCostModeReset"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.governor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.monthly_reset.arn
}

resource "aws_cloudwatch_event_target" "monthly_reset" {
  rule      = aws_cloudwatch_event_rule.monthly_reset.name
  target_id = "cost-governor"
  arn       = aws_lambda_function.governor.arn
  input     = jsonencode({ source = "aws.events", action = "reset-new-budget-month" })

  depends_on = [aws_lambda_permission.monthly_reset]
}

resource "aws_lambda_permission" "sns" {
  for_each = local.control_modes

  statement_id  = "AllowCostControl${replace(title(each.key), "_", "")}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.governor.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.control[each.key].arn
}

resource "aws_sns_topic_subscription" "governor" {
  for_each = local.control_modes

  topic_arn = aws_sns_topic.control[each.key].arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.governor.arn

  depends_on = [aws_lambda_permission.sns]
}

resource "aws_budgets_budget" "monthly" {
  name         = "${var.name_prefix}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 50
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.operations.arn]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 70
    threshold_type            = "PERCENTAGE"
    notification_type         = "FORECASTED"
    subscriber_sns_topic_arns = [aws_sns_topic.operations.arn]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 70
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.operations.arn, aws_sns_topic.control["conserve"].arn]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.operations.arn, aws_sns_topic.control["read_only"].arn]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 90
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.operations.arn, aws_sns_topic.control["suspend"].arn]
  }

  tags = var.tags

  depends_on = [aws_sns_topic_policy.operations, aws_sns_topic_policy.control]
}
