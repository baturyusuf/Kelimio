data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  database_name         = "kelimio"
  database_admin_user   = "kelimio_admin"
  database_runtime_user = "kelimio_runtime"
  database_identifier   = "${var.name_prefix}-postgres"
  api_container_name    = "api"
  api_container_port    = 8080
  matching_key_version  = "production-v${var.matching_secret_version}"
  api_image             = "${var.api_ecr_repository_url}@${var.api_image_digest}"
  database_url          = "jdbc:postgresql://${aws_db_instance.this.address}:${aws_db_instance.this.port}/${local.database_name}?sslmode=verify-full&sslrootcert=/app/rds-global-bundle.pem"
}

ephemeral "random_password" "database_runtime" {
  length           = 48
  special          = true
  override_special = "!#$%&*+-=?^_~"
  min_lower        = 8
  min_upper        = 8
  min_numeric      = 8
  min_special      = 4
}

ephemeral "random_bytes" "matching_replay" {
  length = 32
}

resource "aws_secretsmanager_secret" "database_runtime" {
  name                    = "${var.name_prefix}/database/runtime"
  description             = "Least-privilege PostgreSQL runtime login, generated write-only by Terraform."
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 30
  tags                    = merge(var.tags, { DataClass = "database-credential" })
}

resource "aws_secretsmanager_secret_version" "database_runtime" {
  secret_id                = aws_secretsmanager_secret.database_runtime.id
  secret_string_wo         = jsonencode({ username = local.database_runtime_user, password = ephemeral.random_password.database_runtime.result })
  secret_string_wo_version = var.database_secret_version
}

resource "aws_secretsmanager_secret" "matching_replay" {
  name                    = "${var.name_prefix}/matching-replay"
  description             = "Versioned Type-D replay HMAC keyring, generated write-only by Terraform."
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 30
  tags                    = merge(var.tags, { DataClass = "answer-replay-key" })
}

resource "aws_secretsmanager_secret_version" "matching_replay" {
  secret_id = aws_secretsmanager_secret.matching_replay.id
  secret_string_wo = jsonencode({
    matchingReplayKeys = "${local.matching_key_version}=${ephemeral.random_bytes.matching_replay.base64}"
  })
  secret_string_wo_version = var.matching_secret_version
}

resource "aws_security_group" "api" {
  name        = "${var.name_prefix}-api"
  description = "No public ingress; API Gateway VPC link to the API task only"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name_prefix}-api" })
}

resource "aws_security_group" "vpc_link" {
  name        = "${var.name_prefix}-api-gateway-link"
  description = "API Gateway VPC link ENIs"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name_prefix}-api-gateway-link" })
}

resource "aws_security_group" "database" {
  name        = "${var.name_prefix}-database"
  description = "Private PostgreSQL reachable only by the API and migration tasks"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name_prefix}-database" })
}

resource "aws_vpc_security_group_ingress_rule" "api_from_vpc_link" {
  security_group_id            = aws_security_group.api.id
  referenced_security_group_id = aws_security_group.vpc_link.id
  from_port                    = local.api_container_port
  to_port                      = local.api_container_port
  ip_protocol                  = "tcp"
  description                  = "API Gateway private integration"
}

resource "aws_vpc_security_group_egress_rule" "vpc_link_to_api" {
  security_group_id            = aws_security_group.vpc_link.id
  referenced_security_group_id = aws_security_group.api.id
  from_port                    = local.api_container_port
  to_port                      = local.api_container_port
  ip_protocol                  = "tcp"
  description                  = "API Gateway private integration"
}

resource "aws_vpc_security_group_ingress_rule" "database_from_api" {
  security_group_id            = aws_security_group.database.id
  referenced_security_group_id = aws_security_group.api.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "TLS PostgreSQL from API and migration tasks"
}

resource "aws_vpc_security_group_egress_rule" "api_to_database" {
  security_group_id            = aws_security_group.api.id
  referenced_security_group_id = aws_security_group.database.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "TLS PostgreSQL"
}

# The task has no public ingress and no NAT. It must reach dynamic AWS public
# endpoints and Cognito's public JWKS endpoint, whose addresses cannot be
# represented by a stable allowlist. ADR-018 accepts this TLS-only egress.
#trivy:ignore:AVD-AWS-0104
resource "aws_vpc_security_group_egress_rule" "api_https" {
  security_group_id = aws_security_group.api.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "AWS APIs, Cognito JWKS, ECR and telemetry over TLS"
}

resource "aws_vpc_security_group_egress_rule" "api_dns_udp" {
  security_group_id = aws_security_group.api.id
  cidr_ipv4         = var.vpc_cidr
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
  description       = "VPC DNS"
}

resource "aws_vpc_security_group_egress_rule" "api_dns_tcp" {
  security_group_id = aws_security_group.api.id
  cidr_ipv4         = var.vpc_cidr
  from_port         = 53
  to_port           = 53
  ip_protocol       = "tcp"
  description       = "VPC DNS fallback"
}

resource "aws_db_subnet_group" "this" {
  name        = "${var.name_prefix}-database"
  description = "Two-AZ subnet coverage required by RDS; the database remains Single-AZ"
  subnet_ids  = var.private_subnet_ids
  tags        = var.tags
}

resource "aws_db_parameter_group" "this" {
  name        = "${var.name_prefix}-postgres17"
  family      = "postgres17"
  description = "Kelimio production PostgreSQL privacy and TLS controls"
  tags        = var.tags

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "password_encryption"
    value = "scram-sha-256"
  }

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_statement"
    value = "none"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "-1"
  }

  parameter {
    name  = "log_min_error_statement"
    value = "panic"
  }

  parameter {
    name  = "log_parameter_max_length"
    value = "0"
  }

  parameter {
    name  = "log_parameter_max_length_on_error"
    value = "0"
  }
}

resource "aws_cloudwatch_log_group" "database" {
  for_each = toset(["postgresql", "upgrade"])

  name              = "/aws/rds/instance/${local.database_identifier}/${each.key}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_db_instance" "this" {
  identifier = local.database_identifier

  engine         = "postgres"
  engine_version = var.database_engine_version
  instance_class = var.database_instance_class
  port           = 5432
  db_name        = local.database_name
  username       = local.database_admin_user

  manage_master_user_password   = true
  master_user_secret_kms_key_id = var.kms_key_arn

  allocated_storage     = 20
  max_allocated_storage = 30
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  multi_az               = false
  availability_zone      = var.primary_availability_zone
  publicly_accessible    = false
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.database.id]
  parameter_group_name   = aws_db_parameter_group.this.name

  backup_retention_period   = 7
  backup_window             = "01:00-01:30"
  maintenance_window        = "sun:02:00-sun:03:00"
  copy_tags_to_snapshot     = true
  delete_automated_backups  = false
  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${local.database_identifier}-final"

  auto_minor_version_upgrade          = false
  allow_major_version_upgrade         = false
  apply_immediately                   = false
  iam_database_authentication_enabled = false
  performance_insights_enabled        = false
  monitoring_interval                 = 0
  enabled_cloudwatch_logs_exports     = ["postgresql", "upgrade"]
  ca_cert_identifier                  = "rds-ca-rsa2048-g1"
  engine_lifecycle_support            = "open-source-rds-extended-support-disabled"

  tags = merge(var.tags, { AutoSuspend = "true", DataClass = "system-of-record" })

  depends_on = [aws_cloudwatch_log_group.database]
}

resource "aws_cloudwatch_log_group" "ecs_exec" {
  name              = "/kelimio/${var.environment}/ecs-exec"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}

resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-cluster"

  configuration {
    execute_command_configuration {
      kms_key_id = var.kms_key_arn
      logging    = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.ecs_exec.name
      }
    }
  }

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = var.tags
}

resource "aws_iam_role" "api_execution" {
  name = "${var.name_prefix}-api-execution"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
  tags = var.tags
}

data "aws_iam_policy_document" "api_execution" {
  statement {
    sid       = "GetEcrAuthorization"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "PullOnlyApiImage"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer"
    ]
    resources = [var.api_ecr_repository_arn]
  }

  statement {
    sid       = "WriteApiLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = [var.api_log_group_arn, "${trimsuffix(var.api_log_group_arn, ":*")}:*"]
  }

  statement {
    sid       = "ReadApiSecrets"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.database_runtime.arn, aws_secretsmanager_secret.matching_replay.arn]
  }

  statement {
    sid       = "DecryptApiSecrets"
    actions   = ["kms:Decrypt"]
    resources = [var.kms_key_arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${data.aws_region.current.region}.${data.aws_partition.current.dns_suffix}"]
    }
  }
}

resource "aws_iam_role_policy" "api_execution" {
  name   = "${var.name_prefix}-api-execution"
  role   = aws_iam_role.api_execution.id
  policy = data.aws_iam_policy_document.api_execution.json
}

resource "aws_iam_role" "api_task" {
  name = "${var.name_prefix}-api-task"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
  tags = var.tags
}

data "aws_iam_policy_document" "api_task" {
  statement {
    sid       = "ReadOperatingMode"
    actions   = ["ssm:GetParameter"]
    resources = ["arn:${data.aws_partition.current.partition}:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter${var.operating_mode_parameter_name}"]
  }

  statement {
    sid = "EncryptedAuditedEcsExecChannels"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "DecryptEcsExec"
    actions   = ["kms:Decrypt"]
    resources = [var.kms_key_arn]
  }

  statement {
    sid       = "DescribeEcsExecLogs"
    actions   = ["logs:DescribeLogGroups", "logs:DescribeLogStreams"]
    resources = ["*"]
  }

  statement {
    sid = "WriteAuditedEcsExecLogs"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [aws_cloudwatch_log_group.ecs_exec.arn, "${aws_cloudwatch_log_group.ecs_exec.arn}:*"]
  }
}

resource "aws_iam_role_policy" "api_task" {
  name   = "${var.name_prefix}-api-task"
  role   = aws_iam_role.api_task.id
  policy = data.aws_iam_policy_document.api_task.json
}

resource "aws_iam_role" "migration_execution" {
  name = "${var.name_prefix}-migration-execution"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
  tags = var.tags
}

data "aws_iam_policy_document" "migration_execution" {
  statement {
    sid       = "GetEcrAuthorization"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "PullOnlyApiImage"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer"
    ]
    resources = [var.api_ecr_repository_arn]
  }

  statement {
    sid       = "WriteMigrationLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = [var.api_log_group_arn, "${trimsuffix(var.api_log_group_arn, ":*")}:*"]
  }

  statement {
    sid       = "ReadMigrationSecrets"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_db_instance.this.master_user_secret[0].secret_arn, aws_secretsmanager_secret.database_runtime.arn]
  }

  statement {
    sid       = "DecryptMigrationSecrets"
    actions   = ["kms:Decrypt"]
    resources = [var.kms_key_arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${data.aws_region.current.region}.${data.aws_partition.current.dns_suffix}"]
    }
  }
}

resource "aws_iam_role_policy" "migration_execution" {
  name   = "${var.name_prefix}-migration-execution"
  role   = aws_iam_role.migration_execution.id
  policy = data.aws_iam_policy_document.migration_execution.json
}

resource "aws_iam_role" "migration_task" {
  name = "${var.name_prefix}-migration-task"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
  tags = var.tags
}

resource "aws_ecs_task_definition" "api" {
  family                   = "${var.name_prefix}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.api_execution.arn
  task_role_arn            = aws_iam_role.api_task.arn
  track_latest             = false

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  volume {
    name = "tmp"
  }

  container_definitions = jsonencode([{
    name                   = local.api_container_name
    image                  = local.api_image
    essential              = true
    readonlyRootFilesystem = true
    user                   = "kelimio"
    stopTimeout            = 30
    portMappings = [{
      name          = "http"
      containerPort = local.api_container_port
      hostPort      = local.api_container_port
      protocol      = "tcp"
      appProtocol   = "http"
    }]
    mountPoints = [{
      sourceVolume  = "tmp"
      containerPath = "/tmp"
      readOnly      = false
    }]
    linuxParameters = {
      initProcessEnabled = true
      capabilities       = { drop = ["ALL"] }
    }
    environment = [
      { name = "AWS_REGION", value = var.aws_region },
      { name = "KELIMIO_BUILD_REVISION", value = var.build_revision },
      { name = "KELIMIO_COURSE_RELEASE_ENABLED", value = "false" },
      { name = "KELIMIO_DB_MAX_POOL_SIZE", value = "4" },
      { name = "KELIMIO_DB_MIN_IDLE", value = "1" },
      { name = "KELIMIO_DB_URL", value = local.database_url },
      { name = "KELIMIO_DB_USER", value = local.database_runtime_user },
      { name = "KELIMIO_ENVIRONMENT", value = var.environment },
      { name = "KELIMIO_IMPORT_ENABLED", value = "false" },
      { name = "KELIMIO_LOCAL_COURSE_AUTHORING_ENABLED", value = "false" },
      { name = "KELIMIO_LOCAL_STARTER_COURSE_ENABLED", value = "false" },
      { name = "KELIMIO_MATCHING_REPLAY_ACTIVE_KEY_VERSION", value = local.matching_key_version },
      { name = "KELIMIO_OIDC_AUDIENCE", value = var.oidc_client_id },
      { name = "KELIMIO_OIDC_ISSUER", value = var.oidc_issuer },
      { name = "KELIMIO_OIDC_JWK_SET_URI", value = var.oidc_jwk_set_uri },
      { name = "KELIMIO_OIDC_TOKEN_PROFILE", value = "cognito-access" },
      { name = "KELIMIO_OPERATING_MODE_PARAMETER", value = var.operating_mode_parameter_name },
      { name = "KELIMIO_PROJECTION_ENABLED", value = "true" },
      { name = "KELIMIO_RUNTIME_ROLE", value = "api" },
      { name = "PORT", value = tostring(local.api_container_port) },
      { name = "SPRING_FLYWAY_ENABLED", value = "false" }
    ]
    secrets = [
      { name = "KELIMIO_DB_PASSWORD", valueFrom = "${aws_secretsmanager_secret.database_runtime.arn}:password::" },
      { name = "KELIMIO_MATCHING_REPLAY_KEYS", valueFrom = "${aws_secretsmanager_secret.matching_replay.arn}:matchingReplayKeys::" }
    ]
    healthCheck = {
      command     = ["CMD-SHELL", "wget -qO- http://127.0.0.1:8080/actuator/health/readiness | grep -q '\"status\":\"UP\"'"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 90
    }
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = var.api_log_group_name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "api"
      }
    }
  }])

  tags = var.tags

  depends_on = [
    aws_iam_role_policy.api_execution,
    aws_iam_role_policy.api_task,
    aws_secretsmanager_secret_version.database_runtime,
    aws_secretsmanager_secret_version.matching_replay
  ]
}

resource "aws_ecs_task_definition" "migration" {
  family                   = "${var.name_prefix}-migration"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.migration_execution.arn
  task_role_arn            = aws_iam_role.migration_task.arn
  track_latest             = false

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  volume {
    name = "tmp"
  }

  container_definitions = jsonencode([{
    name                   = "migration"
    image                  = local.api_image
    essential              = true
    readonlyRootFilesystem = true
    user                   = "kelimio"
    mountPoints = [{
      sourceVolume  = "tmp"
      containerPath = "/tmp"
      readOnly      = false
    }]
    linuxParameters = {
      initProcessEnabled = true
      capabilities       = { drop = ["ALL"] }
    }
    environment = [
      { name = "AWS_REGION", value = var.aws_region },
      { name = "KELIMIO_BUILD_REVISION", value = var.build_revision },
      { name = "KELIMIO_COURSE_RELEASE_ENABLED", value = "false" },
      { name = "KELIMIO_DB_MAX_POOL_SIZE", value = "2" },
      { name = "KELIMIO_DB_MIN_IDLE", value = "1" },
      { name = "KELIMIO_DB_NAME", value = local.database_name },
      { name = "KELIMIO_DB_RUNTIME_USER", value = local.database_runtime_user },
      { name = "KELIMIO_DB_URL", value = local.database_url },
      { name = "KELIMIO_ENVIRONMENT", value = var.environment },
      { name = "KELIMIO_IMPORT_ENABLED", value = "false" },
      { name = "KELIMIO_LOCAL_COURSE_AUTHORING_ENABLED", value = "false" },
      { name = "KELIMIO_LOCAL_STARTER_COURSE_ENABLED", value = "false" },
      { name = "KELIMIO_PROJECTION_ENABLED", value = "false" },
      { name = "KELIMIO_RUNTIME_ROLE", value = "migration" },
      { name = "SPRING_FLYWAY_ENABLED", value = "true" },
      { name = "SPRING_MAIN_WEB_APPLICATION_TYPE", value = "none" }
    ]
    secrets = [
      { name = "KELIMIO_DB_USER", valueFrom = "${aws_db_instance.this.master_user_secret[0].secret_arn}:username::" },
      { name = "KELIMIO_DB_PASSWORD", valueFrom = "${aws_db_instance.this.master_user_secret[0].secret_arn}:password::" },
      { name = "KELIMIO_DB_RUNTIME_PASSWORD", valueFrom = "${aws_secretsmanager_secret.database_runtime.arn}:password::" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = var.api_log_group_name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "migration"
      }
    }
  }])

  tags = var.tags

  depends_on = [
    aws_iam_role_policy.migration_execution,
    aws_secretsmanager_secret_version.database_runtime
  ]
}

resource "aws_service_discovery_private_dns_namespace" "this" {
  name        = "kelimio.internal"
  description = "Private API service discovery for API Gateway"
  vpc         = var.vpc_id
  tags        = var.tags
}

resource "aws_service_discovery_service" "api" {
  name          = "api"
  namespace_id  = aws_service_discovery_private_dns_namespace.this.id
  force_destroy = false

  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.this.id
    routing_policy = "MULTIVALUE"

    dns_records {
      ttl  = 10
      type = "SRV"
    }
  }

  health_check_custom_config {}

  tags = var.tags
}

resource "aws_ecs_service" "api" {
  name             = "${var.name_prefix}-api"
  cluster          = aws_ecs_cluster.this.id
  task_definition  = aws_ecs_task_definition.api.arn
  desired_count    = var.api_desired_count
  launch_type      = "FARGATE"
  platform_version = "1.4.0"

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  enable_execute_command             = true
  enable_ecs_managed_tags            = true
  propagate_tags                     = "SERVICE"
  wait_for_steady_state              = true

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = [var.primary_public_subnet_id]
    security_groups  = [aws_security_group.api.id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn   = aws_service_discovery_service.api.arn
    container_name = local.api_container_name
    container_port = local.api_container_port
  }

  tags = merge(var.tags, { AutoSuspend = "true" })

  # Immutable task definitions are created by Terraform, but the guarded
  # release workflow promotes one only after its migration task succeeds.
  # Cost suspension also sets desired_count to zero out of band.
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}

resource "aws_apigatewayv2_vpc_link" "this" {
  name               = "${var.name_prefix}-link"
  subnet_ids         = var.public_subnet_ids
  security_group_ids = [aws_security_group.vpc_link.id]
  tags               = var.tags
}

resource "aws_apigatewayv2_api" "this" {
  name                         = "${var.name_prefix}-api"
  protocol_type                = "HTTP"
  disable_execute_api_endpoint = false
  ip_address_type              = "ipv4"
  tags                         = var.tags
}

resource "aws_apigatewayv2_integration" "api" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  integration_uri        = aws_service_discovery_service.api.arn
  connection_type        = "VPC_LINK"
  connection_id          = aws_apigatewayv2_vpc_link.this.id
  payload_format_version = "1.0"
  timeout_milliseconds   = 30000
  request_parameters = {
    "overwrite:path" = "$request.path"
  }
}

resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.this.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito-access-token"

  jwt_configuration {
    audience = [var.oidc_client_id]
    issuer   = var.oidc_issuer
  }
}

resource "aws_apigatewayv2_route" "authenticated" {
  api_id               = aws_apigatewayv2_api.this.id
  route_key            = "$default"
  target               = "integrations/${aws_apigatewayv2_integration.api.id}"
  authorization_type   = "JWT"
  authorizer_id        = aws_apigatewayv2_authorizer.cognito.id
  authorization_scopes = ["openid"]
}

resource "aws_apigatewayv2_route" "health" {
  for_each = toset([
    "GET /actuator/health",
    "GET /actuator/health/{proxy+}"
  ])

  api_id             = aws_apigatewayv2_api.this.id
  route_key          = each.value
  target             = "integrations/${aws_apigatewayv2_integration.api.id}"
  authorization_type = "NONE"
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/kelimio/${var.environment}/api-gateway"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId        = "$context.requestId"
      requestTime      = "$context.requestTime"
      httpMethod       = "$context.httpMethod"
      routeKey         = "$context.routeKey"
      status           = "$context.status"
      responseLength   = "$context.responseLength"
      integrationError = "$context.integrationErrorMessage"
    })
  }

  default_route_settings {
    detailed_metrics_enabled = false
    throttling_burst_limit   = 20
    throttling_rate_limit    = 10
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "database_cpu" {
  alarm_name          = "${var.name_prefix}-database-cpu-high"
  alarm_description   = "RDS CPU remains above 80 percent"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.this.identifier }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  datapoints_to_alarm = 3
  comparison_operator = "GreaterThanThreshold"
  threshold           = 80
  treat_missing_data  = "missing"
  alarm_actions       = [var.operations_topic_arn]
  ok_actions          = [var.operations_topic_arn]
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "database_storage" {
  alarm_name          = "${var.name_prefix}-database-storage-low"
  alarm_description   = "RDS free storage is below 2 GiB"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.this.identifier }
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  comparison_operator = "LessThanThreshold"
  threshold           = 2147483648
  treat_missing_data  = "missing"
  alarm_actions       = [var.operations_topic_arn]
  ok_actions          = [var.operations_topic_arn]
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "api_errors" {
  alarm_name          = "${var.name_prefix}-api-5xx"
  alarm_description   = "Public API returns repeated server errors"
  namespace           = "AWS/ApiGateway"
  metric_name         = "5xx"
  dimensions          = { ApiId = aws_apigatewayv2_api.this.id, Stage = aws_apigatewayv2_stage.default.name }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.operations_topic_arn]
  ok_actions          = [var.operations_topic_arn]
  tags                = var.tags
}
