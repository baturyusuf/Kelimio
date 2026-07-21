#!/bin/sh
set -eu

if ! awslocal s3api head-bucket --bucket kelimio-local-imports >/dev/null 2>&1; then
  awslocal s3api create-bucket \
    --bucket kelimio-local-imports \
    --create-bucket-configuration LocationConstraint=eu-central-1
fi
awslocal s3api put-bucket-versioning \
  --bucket kelimio-local-imports \
  --versioning-configuration Status=Enabled

if ! awslocal s3api head-bucket --bucket kelimio-local-offline-packages >/dev/null 2>&1; then
  awslocal s3api create-bucket \
    --bucket kelimio-local-offline-packages \
    --create-bucket-configuration LocationConstraint=eu-central-1
fi
awslocal s3api put-bucket-versioning \
  --bucket kelimio-local-offline-packages \
  --versioning-configuration Status=Enabled

awslocal sqs create-queue --queue-name kelimio-worker-dlq
dlq_url="$(awslocal sqs get-queue-url --queue-name kelimio-worker-dlq --query QueueUrl --output text)"
dlq_arn="$(awslocal sqs get-queue-attributes --queue-url "$dlq_url" --attribute-names QueueArn --query Attributes.QueueArn --output text)"

awslocal sqs create-queue \
  --queue-name kelimio-worker \
  --attributes "{\"RedrivePolicy\":\"{\\\"deadLetterTargetArn\\\":\\\"$dlq_arn\\\",\\\"maxReceiveCount\\\":\\\"5\\\"}\"}"

touch /tmp/kelimio-init-complete
