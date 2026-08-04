# AWS infrastructure

Terraform is pinned in `docs/VERSIONS.md`. ADR-018 selects one production-only
AWS environment in account `923300948109`, Region `eu-central-1`, with local
development/acceptance and no persistent cloud staging. The production root now
describes the account-guarded no-NAT network, encrypted private object storage,
worker queues/DLQs, ECR/log lifecycle, immutable import archive retention input,
USD 50 budget notifications, and early cost-governor modes. It now also defines
Cognito Authorization Code + PKCE, verified Google-linking controls, API Gateway
HTTPS, a Cloud Map/VPC Link private integration, one ARM64 Fargate API task, a
private Single-AZ RDS PostgreSQL database, write-only generated Secrets Manager
values, separate migration/runtime identities, alarms and audited ECS Exec.
Deployment and production evidence remain release gates; no resource exists
merely because this configuration validates locally.

State bootstrap is intentionally separate because the state bucket must exist
before an environment can use the S3 backend.

```powershell
cd infrastructure/terraform/bootstrap
terraform init
terraform plan -var="state_bucket_name=<globally-unique-name>"
terraform apply -var="state_bucket_name=<globally-unique-name>"

cd ../environments/production
terraform init -backend-config="bucket=<state-bucket>" -backend-config="key=kelimio/production.tfstate" -backend-config="region=eu-central-1" -backend-config="use_lockfile=true"
terraform plan -var="budget_notification_email=<owner-operations-address>" -var="import_archive_retention_days=<approved-days>" -var="api_image_digest=sha256:<immutable-digest>" -var="build_revision=<full-git-sha>"
```

The bootstrap and production providers both reject any account except
`923300948109`; never override this protection or use a personal long-lived AWS
access key. Initial bootstrap is an owner-controlled one-time operation.
Subsequent CI deployment will use GitHub OIDC and a protected production role.
The email subscription must be confirmed before budget mail is delivered. AWS
cost data is delayed, so the 70%/80%/90% controls reduce risk but do not create a
hard USD 50 billing cap. Cost automation may stop stateless compute and RDS but
must never delete the database, backups or immutable course/audit objects.

The operating modes, incident response and recovery requirements are defined in
[`docs/runbooks/production-cost-controls.md`](../../docs/runbooks/production-cost-controls.md).
The guarded image, migration, activation, Google-secret and evidence sequence is
defined in
[`docs/runbooks/production-deployment.md`](../../docs/runbooks/production-deployment.md).

The legacy `environments/development` root remains only as historical validated
foundation code. ADR-018 forbids applying it to AWS for the initial release.
