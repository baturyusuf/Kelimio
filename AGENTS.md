# Kelimio Repository Instructions

This repository is the production implementation of Kelimio, a multilingual learning and course-marketplace product. Work here must preserve money, entitlement, learning-history, privacy, and content-revision guarantees. A screen that appears to work is not sufficient if its backend authority, audit trail, failure behavior, or release path is missing.

## Read before changing the repository

Read these files in order:

1. `docs/adr/ADR-000-source-of-truth.md`
2. `docs/STATUS.md`
3. `docs/IMPLEMENTATION_PLAN.md`
4. The ADRs related to the area being changed
5. `docs/VERSIONS.md`
6. `docs/OWNER_ACTIONS.md`, `docs/LAUNCH_BLOCKERS.md`, and `docs/RELEASE_CHECKLIST.md` when the work touches an external service or release gate

The governing artifact order is defined in ADR-000. Never resolve a source conflict silently. Record the conflict, decision, rationale, and data or migration effect in an ADR before implementation.

## Non-negotiable engineering rules

- Production and staging must not use fake repositories, fake users, client-asserted scores, client-asserted ad rewards, client-asserted entitlements, or success fallbacks when a real provider is unavailable.
- PostgreSQL is the durable source of truth. Redis, mobile caches, search indexes, and projections must be rebuildable.
- Online answer correctness, score, energy, purchase verification, and entitlement are server-authoritative.
- Online scored learning and offline scoreless practice are different domain modes. Offline answer history is never uploaded as scored activity.
- Learning attempts, score events, energy events, commerce events, audit events, and the transactional outbox are append-only facts.
- Content edits create immutable revisions. Published clients consume an immutable course release; existing records are not edited in place.
- API contracts are versioned in `contracts/`. Mobile and web clients are generated from the contract and mapped into domain models.
- Features may not reach into another backend module's repositories or tables. Use the owning module's application interface or a documented outbox event.
- Mobile domain code must not depend on Flutter widgets, Dio, Drift, or platform SDKs. Billing, ads, push, integrity, and secure storage stay behind adapters.
- Keep accessibility, RTL, observability, security, data deletion, and operational recovery in the initial design rather than as release-time additions.

## Security and external accounts

- Never request, paste, log, or commit credentials, tokens, signing keys, certificates, private keys, store API keys, or production configuration secrets in chat or source control.
- Ask the owner to place secrets in the appropriate secure channel: GitHub Actions Secrets or Environments, AWS Secrets Manager, store-provider secret storage, or an agreed secure file-transfer mechanism.
- It is acceptable to request non-secret identifiers such as account IDs, role ARNs, region names, app IDs, bundle IDs, package names, domains, and provider project IDs.
- Do not add a `NoOp`, permissive fallback, or manual "paid" control to bypass an unavailable provider. Expose `configuration_required` outside production and keep the release blocker open.
- Redact tokens, invitation codes, free-form answers, payment data, and sensitive personal data from logs and analytics.

## Change discipline

- Work only in the directories assigned to the task and preserve unrelated user changes.
- Keep each change vertically coherent: contract, migration, implementation, tests, telemetry, and documentation should move together when applicable.
- Add or update an ADR for a durable architecture or product-semantics decision.
- Update `docs/STATUS.md` and the relevant plan or blocker when a milestone, external dependency, or release condition changes.
- Use the pinned toolchain in `docs/VERSIONS.md`. Dependency upgrades require compatibility checks and a deliberate lockfile update.
- Commit Gradle wrapper files, `pubspec.lock`, the selected Node lockfile, CocoaPods `Podfile.lock`, and `.terraform.lock.hcl`. Do not reintroduce ignore rules for them.
- Do not claim publish readiness while any item in `docs/LAUNCH_BLOCKERS.md` or the mandatory release checklist remains unresolved.

## Verification expectations

Run the narrowest relevant checks during iteration and the full affected suite before handoff. The eventual baseline includes formatting and static analysis, architecture-boundary tests, unit and property tests, real-PostgreSQL integration tests, OpenAPI compatibility tests, Flutter widget/golden/accessibility tests, end-to-end tests, security and dependency scans, migration rehearsal, load/soak tests, and backup-restore evidence.

If a required check cannot run, report the exact reason and leave the corresponding status or release gate open.
