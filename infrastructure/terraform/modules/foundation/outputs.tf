output "kms_key_arn" {
  value = aws_kms_key.application.arn
}

output "bucket_names" {
  value = { for name, bucket in aws_s3_bucket.private : name => bucket.id }
}

output "bucket_arns" {
  value = { for name, bucket in aws_s3_bucket.private : name => bucket.arn }
}

output "worker_queue_url" {
  value = aws_sqs_queue.worker.id
}

output "worker_dlq_url" {
  value = aws_sqs_queue.worker_dlq.id
}

output "import_queue_url" {
  value = aws_sqs_queue.import.id
}

output "import_dlq_url" {
  value = aws_sqs_queue.import_dlq.id
}

output "import_queue_arn" {
  value = aws_sqs_queue.import.arn
}

output "import_queue_name" {
  value = aws_sqs_queue.import.name
}

output "import_dlq_arn" {
  value = aws_sqs_queue.import_dlq.arn
}

output "import_dlq_name" {
  value = aws_sqs_queue.import_dlq.name
}

output "ecr_repository_urls" {
  value = { for name, repository in aws_ecr_repository.service : name => repository.repository_url }
}

output "ecr_repository_arns" {
  value = { for name, repository in aws_ecr_repository.service : name => repository.arn }
}

output "log_group_names" {
  value = { for name, log_group in aws_cloudwatch_log_group.service : name => log_group.name }
}

output "log_group_arns" {
  value = { for name, log_group in aws_cloudwatch_log_group.service : name => log_group.arn }
}
