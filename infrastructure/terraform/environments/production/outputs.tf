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
