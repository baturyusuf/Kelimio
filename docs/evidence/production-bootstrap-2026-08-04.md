# Production bootstrap evidence — 2026-08-04

Scope: ADR-018 one-time access/state bootstrap only. This evidence does not
claim that the Kelimio application runtime is deployed or publish-ready.

## Identity and preflight

- AWS CLI 2.36.15 used a browser-mediated, temporary console login profile;
  no AWS access key was created, displayed, stored in GitHub, or committed.
- STS returned account `923300948109`; the bootstrap provider also enforced
  that exact account and `eu-central-1`.
- Read-only preflight found no existing Kelimio S3 bucket, IAM OIDC provider or
  role, RDS database, ECS cluster, ECR repository, Cognito pool, or API Gateway.

## Reviewed and applied plan

- Source revision: `038adc5` (`Add production identity and AWS runtime`).
- Saved bootstrap plan: **15 add, 0 change, 0 destroy**.
- Apply result: **15 added, 0 changed, 0 destroyed**.
- Created state bucket: `kelimio-terraform-state-923300948109-euc1`.
- Created state KMS key:
  `arn:aws:kms:eu-central-1:923300948109:key/e63235e2-500b-40ec-b23b-cc4a3e8070e8`.
- Created repository/environment-bound OIDC provider and roles:
  `KelimioProductionPlan` and `KelimioProductionDeploy`.
- Trust is limited to audience `sts.amazonaws.com` and subject
  `repo:baturyusuf/Kelimio:environment:production`.

## State and post-apply verification

- Bootstrap state was migrated from the initial local backend to
  `s3://kelimio-terraform-state-923300948109-euc1/kelimio/bootstrap.tfstate`
  with S3 locking and the state KMS key.
- The bucket has versioning, KMS default encryption, TLS-only policy, and all
  four S3 public-access blocks. Terraform prevents bucket destruction.
- A post-migration refresh plan returned **no changes**.
- A local recovery copy is retained outside the repository until remote-state
  recovery evidence is complete; all Terraform state/plan files remain ignored.

## GitHub production environment

- The private repository now has a `production` environment restricted to
  branch `codex/foundation-vertical-slice` for the initial canary work.
- Eight non-secret AWS/deployment variables are installed, and the operations
  address is stored as the masked environment secret
  `AWS_BUDGET_NOTIFICATION_EMAIL`.
- The current GitHub billing plan rejected required-reviewer protection for the
  private repository. Therefore the environment has no reviewer gate yet. The
  workflow still requires an explicit manual dispatch and an explicit
  `activate_api` choice, but public traffic and release remain blocked until a
  supported independent approval control is established.

## Remaining boundary

No VPC, application KMS key, application bucket, budget, Cognito pool, RDS
database, ECS service, API Gateway, or application secret was created by this
bootstrap. Those resources require a separately reviewed production plan and
inactive-first deployment.
