# Production application plan evidence — 2026-08-04

- AWS account: `923300948109`
- AWS region: `eu-central-1`
- Terraform: `1.15.8`
- Remote state: KMS-encrypted, versioned S3 backend with native lock file
- Configuration: Google identity disabled until its owner-managed secret exists;
  API desired count zero; immutable placeholder digest used only for the inactive
  first-foundation plan; import archive retention 90 days

The production configuration passed formatting and validation. A plan against
the real account and protected remote state completed with 148 creates and nine
data-source reads, and no update or delete action. It includes the account-level
USD 50 budget, early cost modes, Cognito, Single-AZ PostgreSQL, private-ingress
Fargate/API Gateway topology, encrypted storage, alarms, and deployment roles
defined by ADR-018.

No application resource was applied by this check. The saved plan was deleted
immediately after its action summary was inspected because plan files can carry
sensitive input values and must not be retained or committed. A new reviewed
plan must be generated from the exact release commit before apply.
