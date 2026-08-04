# Production deployment

This runbook deploys ADR-018 to AWS account `923300948109` in `eu-central-1`.
It never uses a long-lived AWS access key. A completed Terraform plan or a
successful local build is not evidence that production has been deployed.

## One-time owner bootstrap

The owner runs the bootstrap root while authenticated to the exact AWS account:

```powershell
cd infrastructure/terraform/bootstrap
terraform init -backend=false
terraform plan -var="state_bucket_name=<globally-unique-private-state-bucket>"
terraform apply -var="state_bucket_name=<globally-unique-private-state-bucket>"
terraform init -migrate-state -force-copy `
  -backend-config="bucket=<bootstrap-output-state-bucket>" `
  -backend-config="key=kelimio/bootstrap.tfstate" `
  -backend-config="region=eu-central-1" `
  -backend-config="encrypt=true" `
  -backend-config="kms_key_id=<bootstrap-output-state-kms-key-arn>" `
  -backend-config="use_lockfile=true"
```

Record only these non-secret outputs:

- state bucket name;
- state KMS key ARN;
- `KelimioProductionPlan` role ARN;
- `KelimioProductionDeploy` role ARN.

Create a protected GitHub Environment named `production`, require an owner
reviewer, prevent self-review where the plan permits it, restrict deployment to
the approved branch, add `AWS_BUDGET_NOTIFICATION_EMAIL` as an environment
secret, and add the following environment variables:

| Variable | Value |
| --- | --- |
| `AWS_TERRAFORM_STATE_BUCKET` | Bootstrap output. |
| `AWS_TERRAFORM_STATE_KMS_KEY_ARN` | Bootstrap output. |
| `AWS_PRODUCTION_PLAN_ROLE_ARN` | Bootstrap output. |
| `AWS_PRODUCTION_DEPLOY_ROLE_ARN` | Bootstrap output. |
| `AWS_IMPORT_ARCHIVE_RETENTION_DAYS` | Approved immutable original-workbook retention. |
| `AWS_API_IMAGE_DIGEST` | Immutable digest from the latest successfully applied production image. |
| `AWS_API_BUILD_REVISION` | Full Git SHA that produced `AWS_API_IMAGE_DIGEST`. |
| `GOOGLE_IDENTITY_ENABLED` | `false` until the Google secret and linking test are ready. |
| `GOOGLE_IDENTITY_CONFIGURATION_VERSION` | Non-secret rotation marker, initially `not-configured`. |
| `DATABASE_SECRET_VERSION` | `1`; increment only during a coordinated migration-task rotation. |

Do not create AWS access-key GitHub secrets. GitHub obtains a short-lived role
session from the immutable owner-ID/repository-ID and environment-bound OIDC
trust. Before applying bootstrap trust, query GitHub's repository OIDC settings
and record the non-secret `sub_claim_prefix`; repositories created after the
immutable-subject rollout must not use a legacy name-only subject. Confirm that
the local bootstrap state was migrated to `kelimio/bootstrap.tfstate` before
removing any local state copy.

## Plan and first inactive deployment

Before dispatch, `aws freetier get-account-plan-state` must report `PAID`. Do
not reduce RDS backup retention to work around a Free-plan account. The workflow
enforces this check before opening Terraform state. Cost-governor serialization
does not depend on account concurrency quota: verify that its DynamoDB lease
table uses on-demand billing, KMS encryption, TTL, conditional acquisition, and
owner-conditional release. Each enforcement notification must have exactly one
SNS subscriber; verify that the governor forwards only its bounded result to the
operations topic after the control action.

Run **Production Terraform Plan** and review every create/change/delete. Then run
**Production Deploy** with `activate_api=false`.

The deployment workflow:

1. creates the foundation with the ECS service at zero tasks when no production
   state exists;
2. builds one pinned ARM64 image, pushes it to the immutable ECR repository and
   blocks critical/high Trivy findings and critical ECR findings while retaining
   a digest-specific CycloneDX SBOM;
3. applies the digest-addressed API and migration task definitions without
   promoting the API task;
4. runs Flyway with the RDS-managed administrative secret, creates/rotates the
   separate DML-only `kelimio_runtime` login, and exits;
5. leaves the public service at its existing desired count unless the guarded
   activation input is explicitly selected.

After a successful application apply, update `AWS_API_IMAGE_DIGEST` and
`AWS_API_BUILD_REVISION` together in the protected environment, then rerun
**Production Terraform Plan**. The plan must use the source revision that built
the deployed digest, not the current documentation-only commit, and must report
no unintended change before the deployment evidence is accepted.

The ECS service deliberately ignores Terraform changes to task definition and
desired count. Only the release workflow promotes a successfully migrated
immutable task definition; the cost governor can set desired count to zero
without the next Terraform plan silently undoing the suspension.

## Google identity provider

The first inactive apply creates a Secrets Manager secret whose ARN is emitted
as `identity.google_oidc_secret_arn`; it does not create a secret value. In the
AWS console, place exactly this JSON in that secret:

```json
{"clientId":"<Google OAuth client ID>","clientSecret":"<Google OAuth client secret>"}
```

Never paste the values in chat, source control, Terraform variables, workflow
logs, or GitHub repository variables. Set `GOOGLE_IDENTITY_ENABLED=true`, change
`GOOGLE_IDENTITY_CONFIGURATION_VERSION` to an auditable non-secret marker, and
rerun the plan/deploy workflow. The narrow configurator Lambda reads the secret
and creates/updates the Cognito Google provider without returning the value to
Terraform state.

Before activation, prove both identity orders with real verified addresses:

- email/password registration, verification, then Google sign-in reaches the
  same Cognito subject and Kelimio profile;
- Google-first sign-in creates one suppressed canonical native destination, and
  password recovery later reaches that same subject;
- an unverified existing native address, an unverified Google assertion, or an
  ambiguous match fails closed and creates no link.

## Activation and rollback

After the migration, identity, backup and no-public-traffic canary evidence is
captured, rerun **Production Deploy** with `activate_api=true`. The workflow
promotes the new task definition, waits for ECS stability and checks the public
readiness endpoint.

For an application rollback, promote the previous immutable task definition;
never roll the database schema backward in place. Use a tested fix-forward
migration unless a separately rehearsed restore decision is approved. For an
incident or budget suspension, set the operating mode to `SUSPENDED`; the cost
governor scales ECS to zero and repeatedly re-stops the Single-AZ RDS instance.
At 01:15 UTC on the first day of the next AWS budget month the governor resets
the application mode to `NORMAL`, but deliberately does not restart stopped
compute. Review the new-month budget and database state, then use the guarded
deployment activation to restore the API; never start the service by editing
the ECS desired count around the workflow.

## Evidence to retain

Retain the reviewed plan, workflow run and commit SHA, ECR digest and scan result,
migration task ARN/exit code, ECS deployment event, readiness response, Cognito
linking test identifiers with personal data redacted, CloudTrail records, budget
subscription confirmation, backup checkpoint, and rollback decision. Production
traffic remains blocked while any mandatory launch blocker is open.

Use `docs/runbooks/production-database-restore.md` for the private PITR exercise
and retain its measured evidence separately from ordinary deployment evidence.
