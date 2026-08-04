# Inactive Production Deployment Evidence — 2026-08-04

Status: **PASSED FOR THE INACTIVE PRE-TRAFFIC FOUNDATION; NOT PUBLIC OR PUBLISH-READY**

## Scope

This record covers the first complete, inactive ADR-018 application deployment in AWS account `923300948109`, Region `eu-central-1`. The API was intentionally deployed with zero desired tasks and received no public application traffic. It does not close the launch blockers or authorize store submission.

Deployed source revision: `e6e6695f50d80bd64b9549fd5c27f1fb6f06d3d9`

Deployed image digest: `sha256:6c683d0d8d8ec491156d3be0cee35ff7fcc679d64c012726290108bae828dc12`

## Retained GitHub evidence

- [Production deployment run 30924532010](https://github.com/baturyusuf/Kelimio/actions/runs/30924532010) passed the native-platform ARM64 image build, Trivy high/critical gate, digest-specific CycloneDX SBOM retention, ECR critical scan, inactive Terraform apply, and one-shot migration.
- The migration task stopped at `2026-08-04T18:37:31.592+03:00` with exit code `0`. Flyway validated all 13 migrations and found the schema current before the least-privilege runtime database-role reconciliation completed.
- [Post-deployment plan run 30925162124](https://github.com/baturyusuf/Kelimio/actions/runs/30925162124) completed with `No changes. Your infrastructure matches the configuration.`
- The protected GitHub `production` environment pins `AWS_API_IMAGE_DIGEST` to the deployed digest. `AWS_API_BUILD_REVISION` pins drift checks to the revision that produced that image so documentation-only commits cannot replace task definitions.
- [Final main plan run 30926169144](https://github.com/baturyusuf/Kelimio/actions/runs/30926169144) repeated the no-change result after the image/build-revision pin was installed.

## Live AWS observations

| Control | Observation |
| --- | --- |
| AWS account | Paid and active; promotional credit remains account-managed and is not treated as a release guarantee. |
| Operating mode | SSM `/kelimio/production/operating-mode` returned `NORMAL`. |
| Database | `kelimio-production-postgres` is `available`, PostgreSQL 17.5 on `db.t4g.micro`, encrypted, not publicly accessible, deletion-protected, Single-AZ, with seven-day backup retention. |
| API runtime | ECS service `kelimio-production-api` is active with desired/running/pending counts `0/0/0`; public application traffic remains disabled. |
| Cost governor lock | DynamoDB table `kelimio-production-cost-governor-lock` is active, on-demand, and encrypted with the application KMS key. |
| Cost governor canary | A direct invocation returned status `200`, mode `NORMAL`, `changed=false`, and no stopped resources. The conditional lease was released; the table had no retained lock item. |
| Monthly budget | `kelimio-production-monthly` is USD 50 with actual 50%, forecast 70%, actual 70%, actual 80%, and actual 90% notifications. Each notification targets the operations SNS topic. AWS billing latency means this is not a hard cap. |
| Alert delivery | The operations SNS topic has one confirmed subscription and zero pending subscriptions. |
| Cognito | User pool `eu-central-1_jO9MokKQO`, Android client `fjbtkqm379amqc28d8frtprdd`, and the hosted-auth endpoint are applied. No Google identity provider is attached; this fails closed until the owner supplies the Google OAuth configuration through Secrets Manager. |
| Secret custody | The Google client-secret placeholder and generated application/database secrets exist in Secrets Manager. Secret values were not read into this record, chat, source, logs, or artifacts. |

## Open gates retained

- Google OAuth and production SES sending are not configured. Google Cloud configuration is required for Google sign-in; Google Play is not required for this step.
- ECS remains at zero until email/password and Google-linking lifecycle canaries, native redirect/deep-link acceptance, and the complete auth-to-answer pre-traffic canary pass.
- Custom DNS/TLS edge, WAF, production authoring/import worker and private scanner execution, restore evidence, Type-D key rotation/rollback, operational exercises, and independent GitHub approval remain open.
- Legal entity, child-safety/privacy/UGC policies, public legal pages, immutable Android application ID, signing custody, commerce/ads/provider configuration, and Google Play release evidence remain owner/release blockers.

No credential, token, private key, secret value, notification address, or personal data is included in this evidence.

## Follow-up recovery evidence

The restore gate listed above was open when this inactive-deployment record was
captured. It was subsequently exercised without enabling public traffic; see
`docs/evidence/production-database-restore-2026-08-04.md`. Isolated/cross-region
backup custody and ledger export remain open.
