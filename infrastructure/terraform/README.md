# AWS infrastructure

Terraform is pinned in `docs/VERSIONS.md`. The current foundation provisions
networking, encrypted private object storage, worker queues and DLQs, ECR
repositories, and log groups. ECS, RDS, Redis, Cognito, edge/WAF, alarms, and
backup policies are release-blocking modules that follow after the owner confirms
the AWS account, region, domain, budget, and data-residency decisions.

State bootstrap is intentionally separate because the state bucket must exist
before an environment can use the S3 backend.

```powershell
cd infrastructure/terraform/bootstrap
terraform init
terraform apply -var="aws_region=<confirmed-region>" -var="state_bucket_name=<globally-unique-name>"

cd ../environments/development
terraform init -backend-config="bucket=<state-bucket>" -backend-config="key=kelimio/development.tfstate" -backend-config="region=<confirmed-region>" -backend-config="use_lockfile=true"
terraform plan -var="aws_region=<confirmed-region>" -var="expected_account_id=<confirmed-12-digit-account-id>"
```

Do not apply an environment with an assumed region or personal long-lived AWS
access key. CI uses GitHub OIDC and a least-privilege role supplied by the owner.
The development root rejects any other AWS account and cannot be relabeled as
staging or production. Those environments require separate state roots and
owner-approved account/region decisions before they are added.
