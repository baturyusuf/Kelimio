# ADR-018: Production-Only Cost-Guarded AWS Topology

- Status: Accepted
- Date: 2026-08-04
- Decision owners: Product owner and architecture
- Partially supersedes: ADR-001 cloud topology and the multi-environment
  assumptions in the implementation and release plans

## Context

The owner has selected one public production environment in AWS account
`923300948109` for the initial low-traffic Android release. Development and
real-service acceptance continue on the isolated local stack; no persistent
AWS development or staging environment will be funded. The initial users are
in Türkiye, while AWS currently has no Türkiye Region. The technical starting
region is therefore `eu-central-1` (Frankfurt), subject to the still-open legal
approval for cross-border personal-data processing.

The owner accepts a monthly AWS target of USD 30-35, automated conservation
and suspension beginning before USD 50, and the small residual risk that the
invoice can exceed USD 50 because AWS cost data and Budget notifications are
delayed. AWS Budgets is an operational brake, not a hard billing cap.

ADR-001's ECS Fargate, ALB, Multi-AZ RDS, ElastiCache, and always-on worker
baseline cannot fit this budget together. Silent removal of security,
durability, authorization, audit, or release controls would be unacceptable.

## Decision

### Environment and release boundary

- AWS has one environment named `production`. The account ID and region are
  explicit Terraform inputs and the provider rejects any other account.
- The AWS account must use the paid account plan before production apply. The
  Free plan's RDS backup-retention restriction may not be used to weaken PITR.
  Upgrading the account plan does not change the USD 50 budget or early
  suspension policy; remaining AWS promotional credits continue to offset
  eligible charges.
- Developer machines use the local Docker/Android acceptance stack. Local data,
  credentials, identities, and endpoints are never reused by production.
- There is no persistent cloud staging environment. Before real traffic, every
  production change must pass the complete local real-service suite, immutable
  artifact/security gates, a production Terraform plan, migration rehearsal,
  backup checkpoint, and a no-public-traffic production smoke/canary step.
- Removing staging does not waive identity, privacy, child-safety, moderation,
  backup/restore, security, store, or owner-approval gates. Production remains
  fail closed until each affected gate has evidence.

### Initial cost-constrained topology

- Do not provision NAT Gateway, ALB, an always-on import worker, ElastiCache,
  Kubernetes, or billable standby compute/database capacity in a second
  Availability Zone in the initial footprint. RDS requires every DB subnet
  group, including a Single-AZ deployment, to contain subnets in at least two
  Availability Zones. Terraform therefore creates empty public/private subnet
  shells in two AZs while the API task and database each remain single-instance;
  this requirement does not authorize a Multi-AZ database or a second API task.
- Run the stateless API as one small, replaceable Fargate task in a public subnet
  with a public address only for outbound dependency access. Its security group
  accepts no public ingress. API Gateway terminates public HTTPS and reaches the
  task's private address through a VPC link and Cloud Map SRV discovery; no SSH,
  public container port, NAT Gateway, or ALB is created. ECS Exec, when enabled,
  is KMS-encrypted, IAM-controlled, and logged.
- The API task has explicit PostgreSQL and VPC DNS egress plus TLS-only port 443
  egress. The latter is required for dynamic AWS public service endpoints and
  Cognito's public JWKS endpoint in the no-NAT topology; those addresses do not
  provide a stable least-privilege CIDR allowlist. This narrow outbound exception
  never permits public ingress and must be revisited if private endpoints become
  cheaper than the accepted risk or the workload grows beyond the beta footprint.
- Use one Single-AZ RDS PostgreSQL instance as the durable source of truth with
  encryption, automated backups, point-in-time recovery, deletion protection,
  and a restore rehearsal. Availability is intentionally lower than ADR-001;
  data integrity and recoverability are not relaxed.
- Keep Redis optional and absent until a measured production need exists.
  PostgreSQL remains authoritative and every projection remains rebuildable.
- Use private, versioned, encrypted S3 buckets and SQS/DLQ. Course-import work
  runs in an isolated, separately authorized, on-demand worker task with its
  malware scanner rather than consuming continuous compute.
- Use Cognito or an explicitly approved managed OIDC service for app-branded
  email/password and Google sign-in. The broker, not the application, owns
  verified-identity linking under ADR-005.
- The initial broker is Cognito. API clients use Authorization Code + PKCE and
  the backend accepts Cognito access tokens only after signature, issuer,
  `token_use=access`, and app-client `client_id` validation. A Google identity
  can link only through a pre-sign-up broker trigger with a provider-verified
  email: it reuses one verified native destination, creates a suppressed native
  destination after Google proves a new address, and rejects ambiguous or
  unverified matches. The Google client secret remains in Secrets Manager and a
  narrow configurator reads it at apply time; neither Terraform input nor
  application state contains the value.
- Cognito's default sender may be used only for a bounded pre-traffic canary.
  Public registration remains blocked until the owner approves a sender/domain
  and SES production delivery, templates, bounce/complaint handling and quotas.
- Use CloudFront's flat-rate/free edge plan where supported for public delivery
  and WAF/DDoS containment. Unsupported origin, compute, database, storage,
  messaging, email, key, log, domain, tax, and support charges remain normal
  AWS charges and are counted in the account budget.
- Commerce, advertising, payouts, and public authoring remain unavailable in
  production until their real provider and legal controls exist. There is no
  fake paid, consent, moderation, or entitlement success path.

### Cost controls and service degradation

- Configure one account-level USD 50 monthly cost budget and publish all
  thresholds to an encrypted operations topic. Notify at 50%, forecast 70%,
  actual 70%, actual 80%, and actual 90%.
- Target normal spend at USD 30-35. At 70% the application enters conservation
  mode and disables nonessential imports/background work. At 80% it enters a
  server-authoritative read-only mode for new registrations, authoring,
  enrollment, and scored learning. At 90% the public API and on-demand workers
  are suspended after draining bounded in-flight work.
- Database and backup resources are never deleted automatically to meet a
  budget. They may continue to accrue small storage charges after the service
  is suspended. Destructive cost action requires an explicit, recoverable
  backup and owner approval.
- Add service quotas, upload/download bounds, WAF rate limits, log retention,
  image lifecycle rules, and application-level monthly usage counters so a
  single traffic or import burst is bounded independently of delayed billing.
- Automated cost actions must be idempotent, audited, alarmed, reversible at a
  new billing period, and unable to grant access or bypass authorization.
- Each AWS Budget notification uses one SNS subscriber, matching the provider
  limit. Enforcement thresholds publish to their dedicated control topic; only
  the serialized cost governor can forward the bounded action result (never the
  raw cost payload) to the owner-facing operations topic.
- The account's initial Lambda concurrency quota leaves no capacity for a
  reserved-concurrency setting. Cost-governor invocations are instead serialized
  by one KMS-encrypted, on-demand DynamoDB conditional lease with an owner token
  and a 90-second expiry. A competing invocation fails before reading or writing
  operating mode and is retried by its AWS event source; lease release is
  owner-conditional. DynamoDB stores no user, cost-message, or durable domain
  data and remains rebuildable.

### Deployment identity

- GitHub Actions uses no long-lived AWS access key. One production OIDC role
  trusts only the `baturyusuf/Kelimio` repository's protected `production`
  environment and receives only the permissions required to plan/deploy the
  reviewed infrastructure and immutable artifacts.
- GitHub created this repository after its July 2026 immutable-subject rollout.
  IAM therefore matches the owner-ID/repository-ID-bound subject prefix
  `repo:baturyusuf@75681771/Kelimio@1307479021` plus the exact `production`
  environment. The legacy name-only subject is not trusted, so later namespace
  reuse, repository transfer, or recreation cannot inherit production access.
- Runtime API and import-worker identities remain separate from the deployment
  role and from each other. Database roles and secret access are also separate.
- Initial account bootstrap is a one-time owner-controlled action. Subsequent
  deployments use short-lived OIDC credentials and protected approval.

## Consequences

- The first production release is intentionally a low-availability beta: one
  compute node and Single-AZ database can cause downtime. A future availability
  requirement or sustained usage must raise the budget and supersede this ADR
  before adding Multi-AZ, ALB, horizontal scaling, or always-on workers.
- Production and local/test remain strongly separated even without a cloud
  staging account. Risk is managed through immutable artifacts, pre-traffic
  canaries, backups, maintenance windows, and fail-closed configuration.
- USD 50 is not represented as a guaranteed cap. The documented automatic
  brake starts early and preserves data rather than deleting durable state.
- Türkiye launch does not mean Türkiye data residency. Legal approval for
  processing personal data in Frankfurt remains a release blocker.
- This ADR authorizes implementation of the topology. It does not itself
  authorize public traffic, approve legal text, close child-safety policy, or
  create provider/store credentials.
