output "vpc_id" {
  value = module.networking.vpc_id
}

output "public_subnet_ids" {
  value = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.networking.private_subnet_ids
}

output "foundation" {
  value = {
    kms_key_arn         = module.foundation.kms_key_arn
    bucket_names        = module.foundation.bucket_names
    worker_queue_url    = module.foundation.worker_queue_url
    worker_dlq_url      = module.foundation.worker_dlq_url
    import_queue_url    = module.foundation.import_queue_url
    import_dlq_url      = module.foundation.import_dlq_url
    ecr_repository_urls = module.foundation.ecr_repository_urls
    ecr_repository_arns = module.foundation.ecr_repository_arns
  }
}

output "identity" {
  value = {
    user_pool_id           = module.identity.user_pool_id
    user_pool_arn          = module.identity.user_pool_arn
    android_client_id      = module.identity.android_client_id
    issuer                 = module.identity.issuer
    jwk_set_uri            = module.identity.jwk_set_uri
    authorization_base_url = module.identity.authorization_base_url
    google_oidc_secret_arn = module.identity.google_oidc_secret_arn
  }
}

output "cost_controls" {
  value = {
    monthly_budget_name           = module.cost_controls.monthly_budget_name
    operations_topic_arn          = module.cost_controls.operations_topic_arn
    operating_mode_parameter_name = module.cost_controls.operating_mode_parameter_name
    governor_function_arn         = module.cost_controls.governor_function_arn
  }
}

output "runtime" {
  value = {
    api_endpoint                  = module.runtime.api_endpoint
    api_id                        = module.runtime.api_id
    ecs_cluster_name              = module.runtime.ecs_cluster_name
    api_service_name              = module.runtime.api_service_name
    api_task_definition_arn       = module.runtime.api_task_definition_arn
    migration_task_definition_arn = module.runtime.migration_task_definition_arn
    migration_subnet_id           = module.runtime.migration_subnet_id
    task_security_group_id        = module.runtime.task_security_group_id
    database_identifier           = module.runtime.database_identifier
    database_runtime_secret_arn   = module.runtime.database_runtime_secret_arn
    matching_replay_secret_arn    = module.runtime.matching_replay_secret_arn
  }
}
