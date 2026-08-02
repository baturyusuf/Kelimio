#!/bin/sh
set -eu

if ! awslocal s3api head-bucket --bucket kelimio-local-import-quarantine >/dev/null 2>&1; then
  awslocal s3api create-bucket \
    --bucket kelimio-local-import-quarantine \
    --create-bucket-configuration LocationConstraint=eu-central-1
fi
awslocal s3api put-bucket-versioning \
  --bucket kelimio-local-import-quarantine \
  --versioning-configuration Status=Enabled
awslocal s3api put-bucket-lifecycle-configuration \
  --bucket kelimio-local-import-quarantine \
  --lifecycle-configuration '{"Rules":[{"ID":"abort-incomplete-imports","Status":"Enabled","Filter":{"Prefix":"quarantine/"},"AbortIncompleteMultipartUpload":{"DaysAfterInitiation":1}}]}'

if ! awslocal s3api head-bucket --bucket kelimio-local-import-archive >/dev/null 2>&1; then
  awslocal s3api create-bucket \
    --bucket kelimio-local-import-archive \
    --create-bucket-configuration LocationConstraint=eu-central-1
fi
awslocal s3api put-bucket-versioning \
  --bucket kelimio-local-import-archive \
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

awslocal sqs create-queue --queue-name kelimio-import-dlq
import_dlq_url="$(awslocal sqs get-queue-url --queue-name kelimio-import-dlq --query QueueUrl --output text)"
import_dlq_arn="$(awslocal sqs get-queue-attributes --queue-url "$import_dlq_url" --attribute-names QueueArn --query Attributes.QueueArn --output text)"

awslocal sqs create-queue \
  --queue-name kelimio-import \
  --attributes "{\"VisibilityTimeout\":\"480\",\"RedrivePolicy\":\"{\\\"deadLetterTargetArn\\\":\\\"$import_dlq_arn\\\",\\\"maxReceiveCount\\\":\\\"5\\\"}\"}"

touch /tmp/kelimio-init-complete
