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
  Kubernetes, or a second Availability Zone in the initial footprint.
- Run the stateless API on one small, replaceable compute node with a public
  address, no inbound administration port, Systems Manager access, encrypted
  root storage, and HTTPS-only origin access restricted to the approved edge.
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

### Deployment identity

- GitHub Actions uses no long-lived AWS access key. One production OIDC role
  trusts only the `baturyusuf/Kelimio` repository's protected `production`
  environment and receives only the permissions required to plan/deploy the
  reviewed infrastructure and immutable artifacts.
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
