# Implementation Plan

This plan turns the production requirements into vertically verifiable increments. A phase may overlap with non-blocking work from the next phase, but its exit gate may not be waived. External-account delays do not justify fake provider behavior.

## Delivery principles

- Build the riskiest source-of-truth path before broad screen coverage.
- Move contracts, migrations, implementation, tests, telemetry, and operational notes together.
- Keep one modular monolith and explicit module boundaries until measured extraction gates exist.
- Use real local services and official provider sandboxes during development; production release requires production configuration.
- Preserve append-only facts and rebuildable projections from the first migration.
- Keep every environment reproducible through committed wrappers, lockfiles, migrations, and infrastructure code.

## Phase 0 — Foundation and technical proof

Status: in progress.

Implemented so far: repository governance and ADRs; pinned wrappers and lockfiles; OpenAPI plus generated clients; the initial Flyway schema; a verified Docker Compose stack and real-PostgreSQL migration/integration path; backend/mobile/web scaffolds; a repository-managed Android API 36 emulator with device startup/storage tests and an isolated real-registration acceptance runner; Terraform bootstrap/network/foundation; scoring, energy, language, contract, widget, and vertical-slice test coverage; immutable CI supply-chain pins; and a fail-closed XLSX preflight/parser, workbook grammar normalizer, deterministic allocation planner, and complete-preview digest validated against the exact reviewed workbook. The phase remains open because external-provider sandbox proofs, baseline telemetry operations, and the full Phase 0 exit evidence are incomplete.

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

Status: in progress; the local code path exists, but the staging exit gate is not met.

Implemented so far: JWT/OIDC resource-server validation, mobile Authorization Code + PKCE adapter, a server-enforced provisional-user gate and explicit one-time profile/language/time-zone setup, catalog/detail/enrollment, and authoritative Type-A word, Type-B multiple-choice-cloze, privacy-safe Type-C typed-cloze, and Type-D matching attempts. Type D exposes independently ordered target/support arrays, accepts one complete two-to-six-item bijection, and grades all-or-nothing under the attempt's pinned support language. Its durable answer fact retains no submitted mapping or correct-pair count: it contains a random salt, versioned externally keyed HMAC-SHA-256 replay evidence, and required `is_correct`. Authored correct relationships remain only in immutable content tables and are not copied into answer facts, events, logs, outbox payloads, mobile recovery, or diagnostics; the staging/production secret keyring remains external to PostgreSQL and source. Version-specific replay compares in constant time and fails closed for missing or invalid key configuration. HMAC resists candidate testing under database-only compromise while its external key remains secret, but correctness necessarily discloses the authored mapping when true and the sole swap for a false two-pair answer. Persistent idempotency, the authoritative scoring/energy/outbox transaction, generated-client mobile repositories, privacy-safe Drift recovery, owner-scoped lost-response reconciliation, result display, an idempotent rebuildable learner-course progress projection, and real-PostgreSQL local transaction evidence are present. A fail-closed local-development command creates immutable provenance-recorded starter release v4 with five Type-A, one Type-B, the exact reviewed-workbook Type-C row, and one four-pair Type-D question from the unambiguous `EV` group without seeding users or learning results. The backend passes 28 suites and 135/135 tests with no failure, error, or skip; contract generation passes 129/129 Dart tests plus TypeScript CJS/ESM consumers and deterministic regeneration of 158 generated source files; and Flutter analysis plus 117/117 tests pass, including the focused 18/18 accessible Type-D suite. The isolated Android acceptance runner passes a fresh Flyway V8 real-service eight-question A/B/C/D journey using a per-run random 32-byte replay key, with reordered same-map Type-D replay, owner-scoped reconciliation, changed-edge `409` without mutation, 8/8 and 480/480 at projection version 9, private-state purge, isolated cleanup, and unchanged normal services/ADB mappings. Production AWS Secrets Manager key provisioning, rotation/rollback, historical verification-key retention, and staging evidence remain open alongside general profile editing and legal-consent facts, the broader device matrix, remaining projections, production telemetry, production-supported course creation/import, and native Custom Tab/deep-link acceptance.

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

A registered staging user signs in, enrolls, answers a real question against the real backend, and sees backend-calculated score and energy. Repeating the same submission cannot create a second score or energy change. No fake repository is reachable in staging or production builds.

## Phase 2 — Student learning product

Status: in progress; all four question types, the 117-test Flutter suite, and the isolated eight-question Android E2E run locally, while the broader device matrix and remaining student product are open.

Implemented foundation: the Type-D domain/controller/UI path provides an accessible two-stage non-drag interaction with RTL, focus, screen-reader, narrow-layout, and text-scale coverage. It never grades locally, retains no submitted or correct mapping in durable recovery or diagnostics, and rebuilds an empty board after restart unless ownership-scoped no-store reconciliation returns committed feedback. Flutter analysis and all 117 tests pass, including the focused 18/18 Type-D suite, and the updated eight-question Android E2E passes against a fresh Flyway V8 stack using a per-run random 32-byte replay key; these do not replace the supported device matrix.

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

Status: secure parser/planner prototype implemented; production workflow not started.

Foundation evidence: the isolated backend core performs bounded malicious-package preflight, read-only streaming parse, multilingual grammar normalization, deterministic test allocation, and versioned allocation/full-preview digests. It intentionally exposes no upload API or persistence path. The local starter's bounded `EV` matching fixture is not production import conversion: production Type-D group allocation remains fail-closed, and no stored minimum-client/capability publication gate exists yet. The Phase 3 deliverables below remain required before an import can create or change a course.

Deliverables:

- direct presigned S3 upload, completion callback, isolated scanner/parser worker, and immutable original archive;
- workbook normalization, test-mode inheritance, deterministic test allocation, paged preview, and exportable error report;
- explicit production Type-D matching-group allocation/conversion semantics plus a stored minimum-client/capability gate that blocks publication to unsupported clients;
- single idempotent import commit and permanent lock against Excel updates to an existing course;
- mobile teacher tree/editor, validation, drafts, ETag conflicts, diff/reapply, and unsaved-change protection;
- `ContentChangeSet`, immutable revisions, impact analysis, atomic `CourseRelease`, publication outbox event, and rollback by release activation;
- paged idempotent reprojection with progress state, retry, DLQ, reconciliation, and cache invalidation;
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

Status: not started.

Deliverables:

- internal admin with MFA, strong RBAC, just-in-time access, audit, moderation, support, entitlement, import/DLQ, reprojection, payout, and fraud tools;
- public privacy, terms, support, community rules, copyright, and account-deletion pages;
- UGC reporting, blocking, moderation states, appeals, child-safety escalation, and takedown workflows;
- AWS dev/staging/production infrastructure through Terraform: network, ECS API/worker, ALB, WAF/CloudFront, RDS/Aurora, ElastiCache, S3, SQS/DLQ, EventBridge, Cognito/approved OIDC, SES, KMS, Secrets Manager, ECR, DNS/TLS, logging, alarms, and audit; inject the Type-D HMAC keyring from Secrets Manager with least-privilege access, an explicit active version, audited rotation/rollback, retention of every old verification key while its facts remain replayable, and fail-closed missing or unknown-version behavior;
- GitHub Actions OIDC with short-lived roles, protected environments, approval gates, artifact signing, and staged deployment;
- PITR, immutable/cross-account backups where selected, ledger export, restore automation, runbooks, and incident ownership.

Exit gate:

Production-equivalent staging is reproducible from infrastructure code, access is auditable, operational dashboards and alerts cover critical paths, moderation/support workflows operate end to end, and a documented restore exercise meets the current RPO/RTO target.

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

## Deferred scale gates

Do not add Kafka, Kubernetes, service mesh, OpenSearch, service-per-domain databases, or global active-active data merely because a later phase mentions growth. Require an ADR with measured latency/throughput, independent ownership or deploy/scale need, operational capacity, migration/rollback plan, and total-cost impact.
