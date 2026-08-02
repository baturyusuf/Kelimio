# Production Release Checklist

Current state: **BLOCKED — NOT PUBLISH-READY**

This is an evidence checklist, not a statement of completion. Check an item only when the release record links to a reproducible build, automated result, approved external record, screenshot/export from an authoritative provider, or signed owner decision. “Works on my machine,” a mock flow, and a provider sandbox alone are not production evidence.

## Governance and ownership

- [ ] The source-priority ADR and every applicable architecture/product ADR are accepted and match the implementation.
- [ ] `docs/STATUS.md`, `docs/OWNER_ACTIONS.md`, and `docs/LAUNCH_BLOCKERS.md` contain no stale or contradictory claims.
- [ ] Every P0/P1 owner action needed for launch is closed with non-secret evidence.
- [ ] Legal, privacy, security, moderation, fraud, payout, incident, and release owners are named.
- [ ] No critical product rule or external-account dependency is being bypassed by a fake, `NoOp`, manual success flag, or permissive fallback.

## Reproducible source and builds

- [ ] Java, Spring Boot, Gradle, Kotlin, Flutter/Dart, Android/iOS, Node/Next.js, and Terraform match `docs/VERSIONS.md` or a superseding ADR.
- [ ] Gradle wrapper files, Flutter/FVM configuration, application lockfiles, CocoaPods lockfile, and Terraform lockfile are committed.
- [ ] Clean-clone backend, Android, iOS, admin web, public web, contract generation, and Terraform validation builds pass in CI.
- [ ] Generated OpenAPI clients are reproducible and generated-code drift/breaking changes fail CI.
- [ ] Release artifacts include provenance, checksum/signature, dependency inventory, and SBOM.

## Contracts, data, and migrations

- [ ] OpenAPI and event schemas are versioned, backward-compatible, contract-tested, and documented.
- [ ] PostgreSQL constraints enforce key ownership, uniqueness, idempotency, entitlement transaction uniqueness, and immutable ledger expectations.
- [ ] Flyway migrations pass empty-database, existing-snapshot, expand/migrate/contract, rollback/fix-forward, and production-volume rehearsal.
- [ ] Cache, search, mobile read models, and projections are demonstrably rebuildable from PostgreSQL facts.
- [ ] Data retention, deletion, legal hold, audit retention, and user export/delete behavior match approved policy.

## Identity, authorization, and privacy

- [ ] Production managed OIDC uses Authorization Code + PKCE, short-lived access tokens, refresh rotation, state/nonce, and approved callback/deep-link allowlists.
- [ ] Object-level authorization and contextual role/ownership tests cover student, course owner, entitlement holder, moderator, support, finance, and admin paths.
- [ ] Multi-device sessions, recovery, logout, account linking, export, deletion, and compromised-session revocation pass end-to-end tests.
- [ ] Public DTOs cannot expose email, phone, payment, device, security, private account, or store transaction data.
- [ ] Consent, minors/age policy, privacy settings, analytics redaction, retention, and regional requirements are implemented and reviewed.

## Learning, score, energy, and progress

- [ ] Pre-answer and offline payloads plus durable/mobile recovery state contain no answer key; Type D exposes only separate independently ordered target/support arrays. The only client/API responses that may contain that submitted question's correct option for A/B, primary correct-answer text for C, or correct mapping for D are transaction-specific no-store POST or ownership-scoped no-store reconciliation feedback under ADR-000/ADR-008/ADR-009, and correctness is evaluated server-side.
- [ ] Raw/canonical typed answers never enter durable facts, logs, analytics, metrics, outbox events, problem details, or mobile recovery; bounded input, pinned-policy grading, replay, and ownership-scoped reconciliation preserve idempotency without retaining learner text.
- [ ] Type-D submission accepts exactly one complete two-to-six-item bijection and grades it all-or-nothing under the attempt's pinned support language. No explicit submitted/correct mapping or correct-pair count enters durable facts, recovery, logs, analytics, metrics, outbox events, or problem details; the durable fact contains a random salt, HMAC-SHA-256 token, stored key version, and required `is_correct`, with the key external to PostgreSQL and constant-time same-map replay/changed-map conflict. Security acceptance documents and tests the residual correctness inference: true identifies the authored mapping, and a false two-pair result identifies the sole swap.
- [ ] The answer transaction atomically handles revision/attempt validation, submission idempotency, correctness, energy, attempt fact, score event, and outbox.
- [ ] Property and concurrency tests prove score caps, first-answer rules, lifetime monotonicity, energy bounds/regeneration, duplicate/replay safety, and multi-device locking.
- [ ] Completion, revision changes, interruption, repeat attempts, and reprojection semantics match accepted ADRs.
- [ ] Verified-score fraud/anomaly review, leaderboard correction, appeal, and rate-limit behavior are operational.
- [ ] Critical learning paths meet read p95 under 350 ms and answer p95 under 500 ms at the approved load profile.

## Excel import, authoring, and content releases

Local/test upload-through-approval evidence exists under ADR-010. Every item
below remains unchecked until production-equivalent staging and the
course-commit/release path pass.

- [ ] Only `.xlsx` is accepted; file type, size, checksum, malware, zip bomb, XML/path, formula, external-link, Unicode, and resource limits are enforced in an isolated worker.
- [ ] Production import proves checksum-bound multipart upload, exact object-version acceptance and lost-response recovery, queue/DLQ/lease/retry behavior, private malware scanning, immutable quarantine/archive/report provenance, owner-scoped no-store reads, and digest-bound approval.
- [ ] API and worker use separate least-privilege IAM and database identities; the worker has no HTTP/OIDC/replay/cursor secrets or Flyway authority, the API cannot read workbook bytes or reach the scanner, and production KMS/Object Lock/retention/legal-hold/scanner-freshness policy is evidenced.
- [ ] Language-code normalization and test-mode inheritance match ADR-000/ADR-003 and workbook regression fixtures.
- [ ] Deterministic fixed/automatic test allocation passes every required edge case without loss or duplication.
- [ ] Production Type-D workbook conversion has approved and tested matching-group allocation semantics, never guesses pair relationships, and publication is enforced by a stored minimum-client/capability gate for unsupported clients.
- [ ] Upload, preview/error report, approval, and original-file archive are idempotent, immutable, ownership-safe, and auditable.
- [ ] One idempotent import commit creates a course exactly once; a second Excel import cannot update that course, and lost/conflicting commit responses cannot create duplicate revisions or releases.
- [ ] Mobile teacher edits use ETag/If-Match, show conflicts/diffs, and never silently apply last-write-wins.
- [ ] Draft change sets, impact preview, immutable revisions/releases, publication, rollback, package versioning, and idempotent reprojection pass end-to-end and failure tests.
- [ ] A 10,000-row import completes in under 5 minutes and normal projection lag is under 10 seconds at the approved baseline.

## Offline practice

- [ ] Package manifest and files are signed/checksummed, versioned by course release/support language/format, and downloaded through authorized short-lived access.
- [ ] Installation is atomic and preserves the previous valid package on download, checksum, storage, or migration failure.
- [ ] Offline answers, history, score, progress, energy, streak, and leaderboard data cannot enter authoritative online APIs.
- [ ] Logout, account switch, refund/revocation, package expiry/check-after, and paid-content lock behavior match approved entitlement policy.
- [ ] Offline package opening meets p95 under 1 second on the supported lower/mid-tier device set.

## Purchases, entitlement, advertising, and marketplace money

- [ ] Every paid course has unique approved/active Android and iOS non-consumable products with correct localization, territory, price point, and review metadata.
- [ ] Purchase order, signed transaction verification, store-server lookup, uniqueness, entitlement activation, restore, pending state, and cross-device reconciliation pass official sandbox and production-readiness tests.
- [ ] Google RTDN and App Store Server Notifications V2 inboxes are authenticated, idempotent, replayable, monitored, and reconcile refund/void/chargeback state.
- [ ] Course hidden/removed, existing buyer, account deletion, and already-downloaded paid-package behavior match ADR-004 and approved legal policy.
- [ ] AdMob SSV signature verification, nonce/transaction deduplication, delayed verification, provider failure, UMP/ATT, test IDs, and production IDs pass security and consent review.
- [ ] Teacher earnings are append-only and reconcile gross, store fee, tax estimate, commission, net, holds, payouts, refunds, and chargeback reversals against store financial reports.
- [ ] Real KYC/KYB and payout provider onboarding, webhooks, least-privilege operations, exceptions, reconciliation, and audited support paths are production-operational.

## Mobile quality

- [ ] Supported Android API/device classes and iOS versions build, install, update, migrate, deep-link, background, and restore correctly.
- [ ] RTL, BCP 47 locale handling, long translation, dynamic type, screen reader, focus order, contrast, touch targets, reduced motion, and non-drag alternatives pass audit.
- [ ] Cold start p75 is under 2.5 seconds, cached home p75 under 1 second, target rendering/jank/memory/network budgets pass, and crash-free users are at least 99.8%.
- [ ] Billing, ads, push, integrity, secure storage, file picking, app/universal links, and native adapter failure modes pass on real devices.
- [ ] Android AAB and iOS archive are production-signed; signing custody, rotation, backup, and CI access are approved and audited.

## Web, admin, moderation, and support

- [ ] Admin uses MFA, strong RBAC, just-in-time access, session controls, immutable audit, and tested separation of moderation/support/finance privileges.
- [ ] User/course search, moderation, appeals, entitlement review, import/DLQ/reprojection, fraud, payout, reconciliation, and support tools operate on real data with safe controls.
- [ ] Reporting, blocking, content review, takedown, child-safety escalation, and user notification/appeal paths meet approved policy.
- [ ] Public privacy, terms, community, copyright, support, and account deletion/export pages are reachable over production HTTPS and match app/store disclosures.

## Infrastructure, security, and operations

- [ ] Dev, staging, and production are isolated and reproducible through reviewed Terraform with protected state and drift detection.
- [ ] Production uses TLS, WAF/CDN, managed Multi-AZ PostgreSQL, Redis, S3 protections/versioning, SQS/DLQ, KMS, Secrets Manager, least-privilege IAM, CloudTrail, and approved network boundaries. The Type-D replay keyring is injected from AWS Secrets Manager with an explicit active version, least-privilege access, audited rotation/rollback, and retention of every historical verification key while its facts remain replayable.
- [ ] GitHub Actions deploys through OIDC short-lived roles and protected environments; no long-lived cloud key or production secret exists in source, logs, artifacts, or mobile binaries.
- [ ] OpenTelemetry traces, metrics, and redacted structured logs correlate critical paths; SLO dashboards, synthetic checks, alarms, on-call, and runbooks are exercised.
- [ ] Secret, SAST, dependency, license, container/IaC, API authorization, ASVS/MASVS, and penetration checks have no open critical/high finding.
- [ ] Rate limits, abuse detection, WAF rules, replay defenses, audit logs, admin access logs, and security incident response are tested.
- [ ] PITR, snapshots, isolated/cross-region copies as approved, ledger exports, and a restore exercise meet RPO at most 15 minutes and RTO at most 4 hours.

## Test and release evidence

- [ ] Unit/property, architecture, real-service integration, contract, widget/component, golden, accessibility, end-to-end, malicious-input, concurrency, webhook replay, migration, load, soak, and disaster-recovery suites pass.
- [ ] No critical/high defect, security issue, data-integrity discrepancy, unreconciled payment, or unresolved migration risk remains.
- [ ] Development, staging, and production configuration validation fails closed when mandatory provider configuration is absent; Type-D replay startup rejects absent, malformed, duplicate, wrong-length, or unknown-active-version key configuration, and replay fails closed when a stored historical key version is unavailable.
- [ ] Feature flags are not used as authorization; kill switches, canary/blue-green backend release, staged mobile rollout, automatic halt thresholds, rollback/fix-forward, and support communication are rehearsed.
- [ ] Store metadata, privacy/data-safety declarations, age/content rating, reviewer notes/accounts, export compliance, IAP review, signed AAB, and TestFlight archive are accepted or ready for submission.
- [ ] The release owner reviews all evidence, confirms every launch blocker closed, and records the final go/no-go decision.

Until every mandatory item is checked with evidence, Kelimio remains **BLOCKED — NOT PUBLISH-READY**.
