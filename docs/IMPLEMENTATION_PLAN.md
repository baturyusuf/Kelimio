# Implementation Plan

This plan turns the production requirements into vertically verifiable increments. A phase may overlap with non-blocking work from the next phase, but its exit gate may not be waived. External-account delays do not justify fake provider behavior.

## Delivery principles

- Build the riskiest source-of-truth path before broad screen coverage.
- Move contracts, migrations, implementation, tests, telemetry, and operational notes together.
- Keep one modular monolith and explicit module boundaries until measured extraction gates exist.
- Use real local services and official provider sandboxes during development; production release requires production configuration.
- Preserve append-only facts and rebuildable projections from the first migration.
- Keep every environment reproducible through committed wrappers, lockfiles, migrations, and infrastructure code.
- Under ADR-018, persistent cloud development/staging environments are omitted;
  the isolated local real-service stack and one protected production environment
  are the reproducible environment boundary for the initial release.

## Phase 0 — Foundation and technical proof

Status: in progress.

Implemented so far: repository governance and ADRs; pinned wrappers and lockfiles; OpenAPI plus generated clients; the Flyway schema and real-PostgreSQL migration/integration path; backend/mobile/web scaffolds; a repository-managed Android API 24/30/36 emulator smoke matrix plus an isolated real-registration acceptance runner; Terraform bootstrap/network/foundation; scoring, energy, language, contract, widget, and vertical-slice test coverage; immutable CI supply-chain pins; and a fail-closed XLSX parser/planner plus local/test upload, scan, immutable provenance, preview, approval, idempotent draft commit, and explicit initial-publication boundary. The import path passes its isolated real PostgreSQL/S3/SQS/ClamAV/OIDC acceptance journey. The phase remains open because external-provider sandbox proofs, baseline telemetry operations, supported physical-device evidence, and the full Phase 0 exit evidence are incomplete.

Deliverables:

- establish repository governance, accepted ADRs, owner actions, blocker register, and release gates;
- scaffold `backend`, `mobile`, `admin-web`, `public-web`, `contracts`, `infrastructure`, `scripts`, and CI without fake runtime flows;
- enforce the versions in `docs/VERSIONS.md` with Gradle wrapper, Java toolchain, FVM, Node version/lockfile, and Terraform constraints;
- create local PostgreSQL, Redis, S3/SQS-compatible development services, email capture, and malware-scanning path;
- establish OpenAPI versioning/code generation and initial RFC 9457-style typed error contract;
- create the first Flyway migrations for identity/profile, course/language, enrollment, attempt, score, energy, idempotency, and outbox foundations;
- prototype the deterministic Excel planner and malicious-workbook defenses;
- implement property tests for scoring, energy, idempotency, and test allocation;
- prove store purchase, AdMob SSV, managed OIDC, and payout-provider feasibility in official sandbox environments as accounts become available;
- establish formatting, static analysis, architecture tests, dependency scanning, SBOM generation, secret scanning, and baseline telemetry.

Exit gate:

- pinned toolchains and local dependencies start reproducibly;
- migrations apply to an empty database;
- OpenAPI client generation is deterministic;
- scoring and import property tests pass;
- no source conflict needed by Phase 1 remains undocumented.

## Phase 1 — Real auth-to-answer vertical slice

Status: in progress; the local code path and an active, guarded ADR-018
internal-test runtime exist, but the production auth-to-answer exit gate is not
met.

Implemented so far: JWT/OIDC resource-server validation, mobile Authorization Code + PKCE, a server-enforced provisional-user gate, profile/language/time-zone setup, catalog/detail/enrollment, and authoritative Type-A/B/C/D attempts. Type D exposes independently ordered sides, accepts one complete bijection, and grades all-or-nothing under the attempt's pinned support language. Its durable fact retains no submitted mapping or correct-pair count; replay uses a random salt and versioned externally keyed HMAC with constant-time comparison. Authored answer relationships remain in immutable content and the staging/production keyring remains external to PostgreSQL and source.

Persistent idempotency, authoritative scoring/energy/outbox, privacy-safe recovery, owner-scoped lost-response reconciliation, rebuildable release-aware progress, stored capability gates, and real-PostgreSQL evidence are present. The bounded internal-test starter release contains Type-A/B/C/D coverage without seeding users or learning results. The backend, generated contract checks, Flutter analysis/tests, web gates, filesystem scan, and container scan passed before merge. Cognito email/password, linking functions, access-token validation, and Secrets Manager replay-key injection are applied in the active production runtime; the Google provider and approved production email sender remain deliberately unconfigured. The guarded 2026-08-10 deployment applied Flyway V14, promoted one immutable API task, passed database-aware readiness, exposed valid OIDC discovery, and accepted the registered Android PKCE redirect. The isolated Android journey passes learning, reviewed-workbook initial publication, secure editor recovery, a real stale-ETag conflict, explicit reapply, and revision-3 publication. The full native production sign-in/course/answer canary, provider lifecycle configuration, general profile editing, legal consent, supported physical-device evidence, production telemetry, production authoring, replay-key rotation, and Custom Tab/deep-link acceptance remain open.

Deliverables:

- OIDC Authorization Code + PKCE sign-in and secure refresh handling;
- profile/language preferences with app, target, and support language separation;
- real course catalog/detail and public/private enrollment;
- all four online question types with an explicit attempt state machine, raw typed-answer privacy, and complete-bijection Type-D matching backed by random-salt, versioned externally keyed HMAC replay evidence with no explicit durable mapping or correct-pair count, while documenting the required `is_correct` disclosure;
- transactionally authoritative answer handling: revision validation, submission idempotency, server correctness, energy, attempt fact, score event, and outbox;
- synchronous response plus asynchronous progress/profile/ranking projection;
- Flutter generated client, repository, Drift cache, typed errors, and result rendering;
- correlation IDs, redacted logs, traces, metrics, dashboards, and alert skeletons;
- real-PostgreSQL integration tests and backend/mobile end-to-end smoke test.

Exit gate:

A registered production-canary user signs in before public traffic, enrolls,
answers a real question against the protected production backend, and sees
backend-calculated score and energy. Repeating the same submission cannot create
a second score or energy change. No fake repository is reachable in any
production artifact.

## Phase 2 — Student learning product

Status: in progress; all four question types, the 134-test Flutter suite, the isolated combined learning/publication Android E2E, and the repository-managed API 24/30/36 emulator smoke matrix run locally, while supported physical-device/performance coverage and the remaining student product are open.

Implemented foundation: the Type-D domain/controller/UI path provides an accessible two-stage non-drag interaction with RTL, focus, screen-reader, narrow-layout, and text-scale coverage. It never grades locally, retains no submitted or correct mapping in durable recovery or diagnostics, and rebuilds an empty board after restart unless ownership-scoped no-store reconciliation returns committed feedback. The mobile transport centrally advertises `question.matching.v1`; Flutter analysis and all 134 tests pass, including Type-D, resumable teacher, secure editor recovery/conflict, and capability-header coverage. The combined learning, reviewed-workbook publication, and conflict-safe revision-3 authoring Android E2E passes against a fresh Flyway V13 stack using a per-run random replay key; and API 24/Nexus 5, API 30/Pixel 3a, and API 36/Pixel 7 smoke checks pass 15/15. Emulator evidence does not replace supported physical-device, native OIDC, update/migration, accessibility-audit, or performance gates.

Deliverables:

- all four question types, deterministic option/order behavior, and accessibility alternatives;
- test completion, course/unit/test projections, streaks, and verified leaderboard views;
- energy regeneration, interruption, and clear paid-course unlimited-energy presentation;
- discovery, search/filter, invitation redemption, profile, ranking, and privacy controls;
- signed/versioned offline packages in a separate local database, atomic installation, and scoreless local practice;
- notifications with user time zone, quiet hours, consent, and cancellation rules;
- RTL, dynamic type, screen-reader, low/mid-tier device, offline, and poor-network coverage.

Exit gate:

Public/private/free student journeys, every question type, retry/idempotency, score/energy/streak, ranking, and offline scoreless practice pass automated end-to-end tests on the supported device matrix.

## Phase 3 — Teacher import, authoring, and release

Status: in progress. ADR-021's controlled production initial-course path is deployed: managed teacher eligibility, versioned terms acceptance, generated mobile contracts, API outbox dispatch, separate worker IAM/database identity, private versioned KMS storage, digest-pinned ClamAV, and SQS-driven zero-to-one ECS scaling are applied. The protected deployment, empty-queue worker/scanner Fargate health proof, scale-to-zero state, readiness, and no-drift plan pass. ADR-022's production course-tree API is deployed, and the mobile editor now retains the full local tree after a stale ETag, displays base/mine/latest multi-entity paths, and requires an explicit latest-or-reapply choice before saving. The real production workbook/malware/archive/DLQ/natural scale-down and physical-device editor-conflict canaries remain open. Public onboarding/moderation/legal policy and large-page retry/dead reconciliation also remain open.

Foundation evidence: under ADR-010, ADR-011, and ADR-012, the API exposes local/test-only create, status, upload-completion, preview, issues, approval, and commit operations. It binds a canonical multipart plan and checksums to one owner, reconciles the exact versioned S3 object, appends dispatch through the transactional outbox/SQS, and uses bounded worker leases/retries plus a private ClamAV network. The worker retains immutable quarantine/archive/report and scanner/parser provenance, runs the bounded streaming parser/planner, exposes HMAC-bound paged results, and accepts approval only for one exact digest/provenance tuple. Approval itself creates nothing. `xlsx-v2` performs allocation first, then composes only complete two-to-six-row matching groups that remain within one test and have unique target/support labels. A separate idempotent transaction consumes `import-content-v2`, creates one inactive immutable draft hierarchy/change set, stores exact source lineage, runtime options, option localizations, and derived release capabilities, and emits an identifiers-and-counts-only draft event. It creates no enrollment, entitlement, active release, catalog result, or publication, and import enablement still fails outside `local`/`test`. Under ADR-013, owner-scoped impact and activation operations use an exact optimistic binding to atomically switch immutable releases, append an activation fact/outbox event, and schedule paged idempotent reprojection. Active score counts only exact revisions in the active release; lifetime score remains append-only. Release enablement also fails outside `local`/`test`. Under ADR-016, a separate owner-scoped, idempotent local/test API creates a deterministic changed Type-C question/test revision and later immutable draft, records generic append-only source-change bindings, emits identifiers only, rejects stale bases or a second open draft, and remains unavailable in production. Catalog listing filters releases with unsupported capabilities and direct course/enrollment/learning access returns `client-upgrade-required` behind the applicable visibility/ownership boundary; the current Flutter client advertises `question.matching.v1` centrally.

The isolated import acceptance runner passes the reviewed valid workbook through approval, exactly-once draft commit, impact preview, and explicit initial publication; a clean-invalid workbook through deterministic validation failure; and EICAR through malware rejection. It proves that 23 source rows become 14 runtime questions, including three Type-D questions, 12 matching pairs, 36 support translations, and exact Type-A/Type-B runtime options; every source row is linked exactly once and the release stores exactly `question.matching.v1`. It also proves ownership isolation, stale-digest and impact-binding rejection, idempotent replay, immutable hierarchy/activation/outbox facts, exact draft boundary, capability gating, queue drain, and reprojection completion on a fresh V13 stack. A separate real-PostgreSQL integration scenario earns 60 active/lifetime points on the original Type-C revision, publishes a changed later release to reproject active score to zero, rolls back to restore active score to 60 while lifetime stays 60, and creates revision 3 after branching from the rollback. Legacy V9 previews remain approval-only instead of being guessed into commit readiness.

Deliverables:

- complete the production form of the locally proven presigned S3 upload, completion callback, isolated scanner/parser worker, and immutable original archive with separate least-privilege identities, retention/Object Lock/KMS, author eligibility/consent, and production pre-traffic evidence;
- extend the locally proven workbook normalization, test-mode inheritance, deterministic allocation, paged preview, immutable report, and digest-bound approval into the production authoring boundary;
- carry the locally proven Type-D matching-group composition and stored release-capability gate into production with least-privilege identities and retained pre-traffic evidence;
- extend the locally proven single idempotent initial-course commit and impact-bound publication into production controls while permanently forbidding Excel updates to an existing course;
- retain authenticated physical-device evidence for the full-tree editor's ETag failure, base/mine/latest multi-entity comparison, explicit reapply, validation, publication, and recovery behavior;
- extend the proven non-Excel local/test subsequent-release boundary into the production tree editor with eligibility, consent, moderation, and production pre-traffic evidence; never use Excel to update an existing course;
- retain production pre-traffic evidence for paged idempotent reprojection with larger non-empty enrollment snapshots, retry, dead-job reconciliation, and cache invalidation;
- teacher analytics and mobile “view as student” behavior.

Exit gate:

A real workbook imports safely, examples produce deterministic test plans, Type-D groups are converted without guessed relationships, unsupported clients are blocked by a stored publication gate, conflicts never silently overwrite, publishing creates one immutable release, failures keep the old release active, and affected progress is reproducibly reprojected without reducing lifetime score.

## Phase 4 — Commerce, advertising, earnings, and payout

Status: not started; provider and legal actions apply.

Deliverables:

- course-specific Android and iOS non-consumable product provisioning and store-state tracking;
- teacher selection from approved price tiers and explicit “published” versus “sale-ready” states;
- purchase order, store SDK flow, backend verification, transaction uniqueness, entitlement state machine, restore, RTDN, and App Store Server Notifications V2;
- refund/void/chargeback reconciliation and access changes driven by store truth;
- AdMob rewarded-ad SSV signature verification, nonce/transaction idempotency, UMP/ATT policy, and delayed verification UI;
- append-only teacher earnings ledger, store financial reconciliation, holds/reversals, real KYC/KYB, and real payout provider;
- fraud signals, manual review, appeals, and audited support adjustments.

Exit gate:

Official store sandboxes prove purchase, duplicate delivery, restore, refund/revocation, and notification replay. Ad rewards cannot be claimed from a client callback. Payout cannot occur without verified provider and KYC/KYB state. Production commerce remains feature-gated until production accounts and legal gates are complete.

## Phase 5 — Administration, production infrastructure, and operations

Status: in progress. ADR-018 records the production-only account, region, cost
and availability trade-offs. The account-guarded no-NAT Terraform root and
protected state/OIDC bootstrap are applied in account `923300948109`. The
guarded internal-test runtime includes Cognito email/password brokering and linking
functions, a private-ingress ARM64 Fargate task definition, Single-AZ RDS
PostgreSQL, generated write-only secrets, separate migration/runtime database
roles, API Gateway HTTPS, alarms, and monotonic budget/Lambda/SSM brakes. The
immutable image passed scan/SBOM gates, the one-shot Flyway V14 migration exited
successfully, a live cost-governor canary passed, and the guarded 2026-08-10
activation promoted one ECS API task. Database-aware readiness, OIDC discovery,
and the registered Android redirect passed; the digest-pinned post-deployment
plan reports no drift. The operations notification subscription is confirmed.
Google/SES, the full native auth-to-answer canary,
independent GitHub approval, isolated backup custody/ledger export, custom
DNS/WAF, and the production import worker remain open. The same-account PITR
exercise now proves a 5m06s RPO lag and 1h05m42s end-to-end application RTO;
`docs/evidence/production-database-restore-2026-08-04.md` retains the evidence.

Deliverables:

- internal admin with MFA, strong RBAC, just-in-time access, audit, moderation, support, entitlement, import/DLQ, reprojection, payout, and fraud tools;
- public privacy, terms, support, community rules, copyright, and account-deletion pages;
- UGC reporting, blocking, moderation states, appeals, child-safety escalation, and takedown workflows;
- ADR-018 production-only infrastructure through Terraform: no NAT/ALB or
  persistent staging; one replaceable small API node behind approved HTTPS edge,
  Single-AZ RDS PostgreSQL with PITR/deletion protection, on-demand isolated
  API/worker roles, S3, SQS/DLQ, Cognito/approved OIDC, SES, KMS, Secrets Manager,
  ECR, DNS/TLS, logs/alarms/audit, and USD 50 cost controls; inject the Type-D
  HMAC keyring from Secrets Manager with least-privilege access, an explicit
  active version, audited rotation/rollback, retention of every old verification
  key while its facts remain replayable, and fail-closed missing or unknown-version behavior;
- GitHub Actions OIDC with short-lived roles, protected environments, approval gates, artifact signing, and staged deployment;
- PITR, immutable/cross-account backups where selected, ledger export, restore automation, runbooks, and incident ownership.

Exit gate:

The production environment is reproducible from infrastructure code, access is
auditable, the complete local real-service suite and no-public-traffic production
canary pass, operational dashboards and cost/safety alerts cover critical paths,
moderation/support workflows operate end to end, and a documented restore
exercise meets the approved RPO/RTO target.

## Phase 6 — Hardening and release

Status: not started.

Deliverables:

- full unit/property/integration/contract/widget/golden/accessibility/end-to-end suites;
- malicious workbook, webhook replay, concurrency, migration, failure-injection, load, soak, and disaster-recovery tests;
- ASVS/MASVS review, threat-model closure, dependency/SBOM/vulnerability evidence, penetration-test remediation, and privacy review;
- performance budgets: API availability 99.9%, read p95 under 350 ms, answer p95 under 500 ms, 10k-row import under 5 minutes, normal projection under 10 seconds, mobile crash-free at least 99.8%, and device startup/package budgets;
- signed Android AAB, TestFlight archive, store metadata, privacy declarations, reviewer accounts/instructions, staged rollout, kill switch, rollback/fix-forward, and on-call readiness;
- final reconciliation of `docs/OWNER_ACTIONS.md`, `docs/LAUNCH_BLOCKERS.md`, and `docs/RELEASE_CHECKLIST.md`.

Exit gate:

Every mandatory checklist item has objective evidence, no critical/high defect or security finding remains open, production provider configuration is verified, restore evidence is current, and the accountable owner records a go decision. Otherwise the status remains **BLOCKED — NOT PUBLISH-READY**.

## Priority beta product slice — 2026-08-28

Status: implemented locally; production deployment and external-provider acceptance remain open.

ADR-022 adds the owner course list/full editor, immutable draft publication and
abandonment, catalog search/access filters, expiring private invitations,
authoritative completion/streak/history, private-by-default profiles and opt-in
leaderboard, release-pinned checksum-verified offline scoreless practice,
notification and quiet-hour preferences, portable account export, deletion
request/recovery, and Cognito-backed all-device session revocation.

Google identity, SES delivery, Firebase push, approved deletion
retention/anonymisation, moderation/legal policy, real-device acceptance, and
production canaries remain explicit gates; no fake provider fallback is added.
Verification includes the full backend suite, 139 Flutter tests, static
analysis, OpenAPI/schema checks, generated clients, Terraform validation, and
focused V15/V16 PostgreSQL migration tests.

## Deferred scale gates

Do not add Kafka, Kubernetes, service mesh, OpenSearch, service-per-domain databases, or global active-active data merely because a later phase mentions growth. Require an ADR with measured latency/throughput, independent ownership or deploy/scale need, operational capacity, migration/rollback plan, and total-cost impact.
