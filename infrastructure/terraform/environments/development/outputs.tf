output "vpc_id" {
  value = module.networking.vpc_id
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
