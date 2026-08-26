locals {
  database_worker_user = "kelimio_worker"
  worker_image         = "${var.worker_ecr_repository_url}@${var.worker_image_digest}"
  scanner_image        = "${var.scanner_ecr_repository_url}@${var.scanner_image_digest}"
}

ephemeral "random_password" "database_worker" {
  length           = 48
  special          = true
  override_special = "!#$%&*+-=?^_~"
  min_lower        = 8
  min_upper        = 8
  min_numeric      = 8
  min_special      = 4
}

ephemeral "random_bytes" "import_cursor" {
  length = 32
}

resource "aws_secretsmanager_secret" "database_worker" {
  name                    = "${var.name_prefix}/database/import-worker"
  description             = "Isolated PostgreSQL login for the course-import worker."
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 30
  tags                    = merge(var.tags, { DataClass = "database-credential" })
}

resource "aws_secretsmanager_secret_version" "database_worker" {
  secret_id                = aws_secretsmanager_secret.database_worker.id
  secret_string_wo         = jsonencode({ username = local.database_worker_user, password = ephemeral.random_password.database_worker.result })
  secret_string_wo_version = var.worker_database_secret_version
}

resource "aws_secretsmanager_secret" "import_cursor" {
  name                    = "${var.name_prefix}/course-import/cursor-hmac"
  description             = "Server-only HMAC key for authenticated course-import cursors."
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 30
  tags                    = merge(var.tags, { DataClass = "pagination-authentication-key" })
}

resource "aws_secretsmanager_secret_version" "import_cursor" {
  secret_id                = aws_secretsmanager_secret.import_cursor.id
  secret_string_wo         = jsonencode({ key = ephemeral.random_bytes.import_cursor.base64 })
  secret_string_wo_version = var.import_cursor_secret_version
}

data "aws_iam_policy_document" "api_import_execution" {
  statement {
    sid       = "ReadImportCursorSecret"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.import_cursor.arn]
  }
  statement {
    sid       = "DecryptImportCursorSecret"
    actions   = ["kms:Decrypt"]
    resources = [var.kms_key_arn]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${data.aws_region.current.region}.${data.aws_partition.current.dns_suffix}"]
    }
  }
}

resource "aws_iam_role_policy" "api_import_execution" {
  name   = "${var.name_prefix}-api-import-execution"
  role   = aws_iam_role.api_execution.id
  policy = data.aws_iam_policy_document.api_import_execution.json
}

data "aws_iam_policy_document" "api_import_task" {
  statement {
    sid       = "InspectImportBuckets"
    actions   = ["s3:GetBucketVersioning", "s3:ListBucketVersions"]
    resources = [var.import_quarantine_bucket_arn, var.import_archive_bucket_arn]
  }
  statement {
    sid = "ManageQuarantineUploads"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetObject",
      "s3:GetObjectAttributes",
      "s3:GetObjectVersion",
      "s3:ListMultipartUploadParts",
      "s3:PutObject"
    ]
    resources = ["${var.import_quarantine_bucket_arn}/quarantine/*"]
  }
  statement {
    sid       = "PublishImportCommands"
    actions   = ["sqs:GetQueueUrl", "sqs:SendMessage"]
    resources = [var.import_queue_arn]
  }
  statement {
    sid       = "UseImportEncryption"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "api_import_task" {
  name   = "${var.name_prefix}-api-import-task"
  role   = aws_iam_role.api_task.id
  policy = data.aws_iam_policy_document.api_import_task.json
}

resource "aws_security_group" "import_worker" {
  name        = "${var.name_prefix}-import-worker"
  description = "No ingress; ephemeral course-import worker and scanner task"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name_prefix}-import-worker" })
}

resource "aws_vpc_security_group_ingress_rule" "database_from_import_worker" {
  security_group_id            = aws_security_group.database.id
  referenced_security_group_id = aws_security_group.import_worker.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "TLS PostgreSQL from isolated import worker"
}

resource "aws_vpc_security_group_egress_rule" "import_worker_to_database" {
  security_group_id            = aws_security_group.import_worker.id
  referenced_security_group_id = aws_security_group.database.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "TLS PostgreSQL"
}

# Dynamic AWS service endpoints require TLS-only public egress in the no-NAT beta VPC.
#trivy:ignore:AVD-AWS-0104
resource "aws_vpc_security_group_egress_rule" "import_worker_https" {
  security_group_id = aws_security_group.import_worker.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "ECR, S3, SQS, Secrets Manager and ClamAV definitions over TLS"
}

resource "aws_vpc_security_group_egress_rule" "import_worker_dns_udp" {
  security_group_id = aws_security_group.import_worker.id
  cidr_ipv4         = var.vpc_cidr
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
  description       = "VPC DNS"
}

resource "aws_vpc_security_group_egress_rule" "import_worker_dns_tcp" {
  security_group_id = aws_security_group.import_worker.id
  cidr_ipv4         = var.vpc_cidr
  from_port         = 53
  to_port           = 53
  ip_protocol       = "tcp"
  description       = "VPC DNS fallback"
}

resource "aws_iam_role" "import_worker_execution" {
  name = "${var.name_prefix}-import-worker-execution"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
  tags = var.tags
}

data "aws_iam_policy_document" "import_worker_execution" {
  statement {
    sid       = "GetEcrAuthorization"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid       = "PullWorkerAndScannerImages"
    actions   = ["ecr:BatchCheckLayerAvailability", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"]
    resources = [var.worker_ecr_repository_arn, var.scanner_ecr_repository_arn]
  }
  statement {
    sid     = "WriteImportLogs"
    actions = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = [
      var.worker_log_group_arn,
      "${trimsuffix(var.worker_log_group_arn, ":*")}:*",
      var.scanner_log_group_arn,
      "${trimsuffix(var.scanner_log_group_arn, ":*")}:*"
    ]
  }
  statement {
    sid       = "ReadWorkerSecret"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.database_worker.arn]
  }
  statement {
    sid       = "DecryptWorkerSecret"
    actions   = ["kms:Decrypt"]
    resources = [var.kms_key_arn]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${data.aws_region.current.region}.${data.aws_partition.current.dns_suffix}"]
    }
  }
}

resource "aws_iam_role_policy" "import_worker_execution" {
  name   = "${var.name_prefix}-import-worker-execution"
  role   = aws_iam_role.import_worker_execution.id
  policy = data.aws_iam_policy_document.import_worker_execution.json
}

resource "aws_iam_role" "import_worker_task" {
  name = "${var.name_prefix}-import-worker-task"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
  tags = var.tags
}

data "aws_iam_policy_document" "import_worker_task" {
  statement {
    sid       = "ReadQuarantine"
    actions   = ["s3:GetObject", "s3:GetObjectAttributes", "s3:GetObjectVersion", "s3:ListBucketVersions"]
    resources = [var.import_quarantine_bucket_arn, "${var.import_quarantine_bucket_arn}/quarantine/*"]
  }
  statement {
    sid       = "WriteVerifiedArchive"
    actions   = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject"]
    resources = ["${var.import_archive_bucket_arn}/archive/*"]
  }
  statement {
    sid       = "ConsumeImportCommands"
    actions   = ["sqs:ChangeMessageVisibility", "sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:GetQueueUrl", "sqs:ReceiveMessage"]
    resources = [var.import_queue_arn]
  }
  statement {
    sid       = "DeadLetterFailedImports"
    actions   = ["sqs:GetQueueUrl", "sqs:SendMessage"]
    resources = [var.import_dlq_arn]
  }
  statement {
    sid       = "UseImportEncryption"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "import_worker_task" {
  name   = "${var.name_prefix}-import-worker-task"
  role   = aws_iam_role.import_worker_task.id
  policy = data.aws_iam_policy_document.import_worker_task.json
}

resource "aws_ecs_task_definition" "import_worker" {
  family                   = "${var.name_prefix}-import-worker"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "3072"
  execution_role_arn       = aws_iam_role.import_worker_execution.arn
  task_role_arn            = aws_iam_role.import_worker_task.arn
  track_latest             = false
  enable_fault_injection   = false

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  volume {
    name                = "worker-tmp"
    configure_at_launch = false
  }

  container_definitions = jsonencode([
    {
      name                   = "scanner"
      image                  = local.scanner_image
      essential              = true
      readonlyRootFilesystem = false
      environment = [
        { name = "KELIMIO_CLAMAV_FUTURE_SKEW_SECONDS", value = "300" },
        { name = "KELIMIO_CLAMAV_MAX_DEFINITION_AGE_SECONDS", value = "86400" }
      ]
      linuxParameters = { initProcessEnabled = true, capabilities = { add = [], drop = ["ALL"] } }
      portMappings    = []
      mountPoints     = []
      volumesFrom     = []
      systemControls  = []
      healthCheck = {
        command     = ["CMD-SHELL", "/usr/local/bin/kelimio-clamav-healthcheck"]
        interval    = 30
        timeout     = 10
        retries     = 5
        startPeriod = 180
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.scanner_log_group_name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "scanner"
        }
      }
    },
    {
      name                   = "import-worker"
      image                  = local.worker_image
      essential              = true
      readonlyRootFilesystem = true
      user                   = "kelimio"
      stopTimeout            = 120
      dependsOn              = [{ containerName = "scanner", condition = "HEALTHY" }]
      portMappings           = []
      mountPoints            = [{ sourceVolume = "worker-tmp", containerPath = "/tmp", readOnly = false }]
      volumesFrom            = []
      systemControls         = []
      # The upstream entrypoint creates runtime directories and drops to its
      # clamav account. These are the minimum capabilities verified against
      # the pinned image; the worker container itself retains no capabilities.
      linuxParameters = {
        initProcessEnabled = true
        capabilities = {
          add  = ["CHOWN", "DAC_OVERRIDE", "FOWNER", "SETGID", "SETUID"]
          drop = ["ALL"]
        }
      }
      environment = [
        { name = "AWS_REGION", value = var.aws_region },
        { name = "KELIMIO_BUILD_REVISION", value = var.build_revision },
        { name = "KELIMIO_CLAMAV_FUTURE_SKEW_SECONDS", value = "300" },
        { name = "KELIMIO_CLAMAV_HOST", value = "127.0.0.1" },
        { name = "KELIMIO_CLAMAV_MAX_DEFINITION_AGE_SECONDS", value = "86400" },
        { name = "KELIMIO_CLAMAV_MIN_ENGINE_VERSION", value = "1.4.0" },
        { name = "KELIMIO_CLAMAV_MIN_SIGNATURE_NUMBER", value = "1" },
        { name = "KELIMIO_CLAMAV_PORT", value = "3310" },
        { name = "KELIMIO_COURSE_RELEASE_ENABLED", value = "false" },
        { name = "KELIMIO_DB_MAX_POOL_SIZE", value = "2" },
        { name = "KELIMIO_DB_MIN_IDLE", value = "1" },
        { name = "KELIMIO_DB_URL", value = local.database_url },
        { name = "KELIMIO_DB_USER", value = local.database_worker_user },
        { name = "KELIMIO_ENVIRONMENT", value = var.environment },
        { name = "KELIMIO_IMPORT_ARCHIVE_BUCKET", value = var.import_archive_bucket_name },
        { name = "KELIMIO_IMPORT_DLQ_NAME", value = var.import_dlq_name },
        { name = "KELIMIO_IMPORT_ENABLED", value = "true" },
        { name = "KELIMIO_IMPORT_QUARANTINE_BUCKET", value = var.import_quarantine_bucket_name },
        { name = "KELIMIO_IMPORT_QUEUE_NAME", value = var.import_queue_name },
        { name = "KELIMIO_LOCAL_COURSE_AUTHORING_ENABLED", value = "false" },
        { name = "KELIMIO_LOCAL_STARTER_COURSE_ENABLED", value = "false" },
        { name = "KELIMIO_PROJECTION_ENABLED", value = "false" },
        { name = "KELIMIO_PRODUCTION_TEACHER_FEATURES_ENABLED", value = tostring(var.production_teacher_features_enabled) },
        { name = "KELIMIO_RUNTIME_ROLE", value = "worker" },
        { name = "SPRING_FLYWAY_ENABLED", value = "false" },
        { name = "SPRING_MAIN_WEB_APPLICATION_TYPE", value = "none" }
      ]
      secrets = [
        { name = "KELIMIO_DB_PASSWORD", valueFrom = "${aws_secretsmanager_secret.database_worker.arn}:password::" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.worker_log_group_name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "worker"
        }
      }
    }
  ])

  tags = var.tags
  depends_on = [
    aws_iam_role_policy.import_worker_execution,
    aws_iam_role_policy.import_worker_task,
    aws_secretsmanager_secret_version.database_worker
  ]
}

resource "aws_ecs_service" "import_worker" {
  name             = "${var.name_prefix}-import-worker"
  cluster          = aws_ecs_cluster.this.id
  task_definition  = aws_ecs_task_definition.import_worker.arn
  desired_count    = 0
  launch_type      = "FARGATE"
  platform_version = "1.4.0"

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100
  enable_execute_command             = false
  enable_ecs_managed_tags            = true
  propagate_tags                     = "SERVICE"
  wait_for_steady_state              = false

  network_configuration {
    subnets          = [var.primary_public_subnet_id]
    security_groups  = [aws_security_group.import_worker.id]
    assign_public_ip = true
  }

  tags = merge(var.tags, { AutoSuspend = "true" })

  lifecycle {
    ignore_changes = [desired_count]
  }
}

resource "aws_appautoscaling_target" "import_worker" {
  max_capacity       = var.production_teacher_features_enabled ? 1 : 0
  min_capacity       = 0
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.import_worker.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "import_worker_out" {
  name               = "${var.name_prefix}-import-worker-out"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.import_worker.resource_id
  scalable_dimension = aws_appautoscaling_target.import_worker.scalable_dimension
  service_namespace  = aws_appautoscaling_target.import_worker.service_namespace
  step_scaling_policy_configuration {
    adjustment_type         = "ExactCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"
    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
    }
  }
}

resource "aws_appautoscaling_policy" "import_worker_in" {
  name               = "${var.name_prefix}-import-worker-in"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.import_worker.resource_id
  scalable_dimension = aws_appautoscaling_target.import_worker.scalable_dimension
  service_namespace  = aws_appautoscaling_target.import_worker.service_namespace
  step_scaling_policy_configuration {
    adjustment_type         = "ExactCapacity"
    cooldown                = 300
    metric_aggregation_type = "Maximum"
    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = 0
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "import_worker_queue_nonempty" {
  alarm_name          = "${var.name_prefix}-import-queue-nonempty"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 0
  alarm_actions       = [aws_appautoscaling_policy.import_worker_out.arn]
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "total"
    expression  = "visible + inflight"
    label       = "Import messages requiring a worker"
    return_data = true
  }
  metric_query {
    id = "visible"
    metric {
      metric_name = "ApproximateNumberOfMessagesVisible"
      namespace   = "AWS/SQS"
      period      = 60
      stat        = "Maximum"
      dimensions  = { QueueName = var.import_queue_name }
    }
  }
  metric_query {
    id = "inflight"
    metric {
      metric_name = "ApproximateNumberOfMessagesNotVisible"
      namespace   = "AWS/SQS"
      period      = 60
      stat        = "Maximum"
      dimensions  = { QueueName = var.import_queue_name }
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "import_worker_queue_empty" {
  alarm_name          = "${var.name_prefix}-import-queue-empty"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 5
  datapoints_to_alarm = 5
  threshold           = 0
  alarm_actions       = [aws_appautoscaling_policy.import_worker_in.arn]
  treat_missing_data  = "breaching"

  metric_query {
    id          = "total"
    expression  = "visible + inflight"
    label       = "Import messages requiring a worker"
    return_data = true
  }
  metric_query {
    id = "visible"
    metric {
      metric_name = "ApproximateNumberOfMessagesVisible"
      namespace   = "AWS/SQS"
      period      = 60
      stat        = "Maximum"
      dimensions  = { QueueName = var.import_queue_name }
    }
  }
  metric_query {
    id = "inflight"
    metric {
      metric_name = "ApproximateNumberOfMessagesNotVisible"
      namespace   = "AWS/SQS"
      period      = 60
      stat        = "Maximum"
      dimensions  = { QueueName = var.import_queue_name }
    }
  }
}
