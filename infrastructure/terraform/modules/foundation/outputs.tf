output "kms_key_arn" {
  value = aws_kms_key.application.arn
}

output "bucket_names" {
  value = { for name, bucket in aws_s3_bucket.private : name => bucket.id }
}

output "worker_queue_url" {
  value = aws_sqs_queue.worker.id
}

output "worker_dlq_url" {
  value = aws_sqs_queue.worker_dlq.id
}

output "ecr_repository_urls" {
  value = { for name, repository in aws_ecr_repository.service : name => repository.repository_url }
}
