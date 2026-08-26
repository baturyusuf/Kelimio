output "api_endpoint" {
  value = aws_apigatewayv2_api.this.api_endpoint
}

output "api_id" {
  value = aws_apigatewayv2_api.this.id
}

output "ecs_cluster_arn" {
  value = aws_ecs_cluster.this.arn
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "api_service_arn" {
  value = aws_ecs_service.api.id
}

output "api_service_name" {
  value = aws_ecs_service.api.name
}

output "api_task_definition_arn" {
  value = aws_ecs_task_definition.api.arn
}

output "migration_task_definition_arn" {
  value = aws_ecs_task_definition.migration.arn
}

output "task_security_group_id" {
  value = aws_security_group.api.id
}

output "migration_subnet_id" {
  value = var.primary_public_subnet_id
}

output "database_identifier" {
  value = aws_db_instance.this.identifier
}

output "database_endpoint" {
  value     = aws_db_instance.this.endpoint
  sensitive = true
}

output "database_runtime_secret_arn" {
  value = aws_secretsmanager_secret.database_runtime.arn
}

output "matching_replay_secret_arn" {
  value = aws_secretsmanager_secret.matching_replay.arn
}

output "import_worker_service_name" {
  value = aws_ecs_service.import_worker.name
}

output "import_worker_task_definition_arn" {
  value = aws_ecs_task_definition.import_worker.arn
}

output "import_worker_security_group_id" {
  value = aws_security_group.import_worker.id
}

output "database_worker_secret_arn" {
  value = aws_secretsmanager_secret.database_worker.arn
}
