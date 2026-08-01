# Project Status

Last updated: 2026-08-01

## Overall status

**BLOCKED — external owner action required; NOT PUBLISH-READY**

Kelimio now has a locally buildable Phase 0 foundation, a healthy Docker-backed development stack, a verified Android debug runtime, a secure deterministic Excel-preview core, and a partial Phase 1 auth-to-answer implementation. This is engineering progress, not a release: there is no deployed staging or production environment, no production-signed store artifact exists, and the owner/provider/legal gates remain open.

## Current phase

| Area | State | Evidence or next gate |
| --- | --- | --- |
| Source review and conflict register | Complete | `docs/adr/ADR-000-source-of-truth.md` |
| Governance foundation | Complete | Root guidance and `docs/` control documents |
| Version and supply-chain baseline | Implemented with one native-platform gap | Modern Gradle wrappers, non-CocoaPods lockfiles, exact runtime pins, immutable CI action SHAs, generator image digest, and image SBOM/scan steps exist; `ios/Podfile.lock` still requires a macOS run |
| Monorepo application scaffold | Implemented; Phase 0 remains open | Backend, mobile, two web deployments, contracts, local services, Terraform, and CI exist and pass the available static/build checks |
| Real auth-to-answer vertical slice | Local real-service path verified; Phase 1 staging gate open | OIDC resource server, real PKCE protocol exchange, explicit first-login profile setup, catalog, enrollment, mixed Type-A/Type-B attempt, idempotent answer, score/energy facts, outbox write, rebuildable course-progress projection, and the production downstream Flutter path pass an isolated Android E2E; native AppAuth sign-in UI and staging proof remain open |
| Student product | In progress beyond the first slice | Type A and accessible/bidirectional Type B run locally; Type C/D and the rest of the Phase 2 exit gate remain open |
| Teacher import and authoring | Secure preview core implemented; production workflow and authoring absent | The reviewed workbook passes fail-closed XLSX preflight, grammar normalization, deterministic allocation, and full-preview digest tests; Phase 3 still requires upload/scanning/archive/approval/commit, schema, authoring, release, and reprojection |
| Commerce, ads, earnings, and payout | Not started | Phase 4 exit gate and owner/provider actions |
| Admin, infrastructure, and operations | Foundation only | Admin fails closed; Terraform currently covers bootstrap/network/foundation, not a production environment |
| Hardening and store release | Not started | Phase 6 and `docs/RELEASE_CHECKLIST.md` |

## Implemented evidence

- `contracts/openapi/kelimio-api.yaml` keeps Type-A and Type-B attempt payloads answer-key-free and accepts no client-owned score, energy, entitlement, or user identity. Under ADR-000, only the response after an answer is committed reveals that submitted question's correct option for feedback. The Type-B contract requires exactly one literal `---`, including overlapping-marker rejection. The profile contract exposes provisional/completed state and accepts a one-time setup command without treating it as legal consent.
- The generation script produces checked-in Dart/Dio and TypeScript clients with a pinned OpenAPI Generator; schema tests cover course, profile, and A/B question responses/requests, required properties, closed objects, canonical language tags, exact Type-B marker structure, and rejected client-asserted identity or answer-key fields.
- The Kotlin/Spring API has Flyway schema, fail-closed Type-A/Type-B storage-to-API mapping, real JWT validation, sanitized provisional identity claims, a server-enforced provisional-profile gate, one-time idempotent profile setup with append-only audit/outbox facts, catalog/enrollment/attempt endpoints, persistent idempotency, authoritative scoring and free-course energy rules, release-pinned manifests, cross-checked append-only facts, transactional outbox transport writes, and a retrying idempotent learner-course progress projection that can be rebuilt from PostgreSQL facts.
- A separately gated local-development command creates one immutable, provenance-recorded mixed Type-A/Type-B starter release from the supported reviewed-workbook subset using English as its support language. It requires authentication, is idempotent, cannot run outside `local`, and creates no user, learning result, entitlement, or production fallback.
- The isolated Excel-preview core snapshots and preflights XLSX packages before read-only SAX parsing, rejects formulas, hidden/active/external content and bounded-resource violations, normalizes the reviewed multilingual workbook grammar without translation fallbacks, deterministically allocates tests, and emits separate allocation and complete-preview SHA-256 digests. Its exact owner-supplied workbook fixture and malicious-package/property tests are checked in; no API, persistence, or release side effect is attached to this core.
- The Flutter client uses the generated API client, AppAuth, secure token storage, Riverpod, `go_router`, Dio, Drift recovery state, generation-guarded and serialized token persistence, private-state purge on session changes (including user-scoped progress), distinct authentication/authorization failures, first-login profile/language/time-zone setup, Turkish/English/Arabic localization, RTL-aware UI, an accessible first-strong-character-directed Type-B inline blank, an explicitly local-only starter-course control, preferred support-language defaults, and bounded/backed-off projected-progress refresh that becomes a retryable error instead of an endless spinner.
- The repository-managed Android API 36 emulator cold-boots without Google Play, maps the local API/OIDC ports through ADB, and has exercised secure storage, the Drift recovery database, session restoration, and signed-out startup on a real Android runtime.
- The internal admin deployment always returns not found until server-side OIDC, MFA, RBAC, and audit exist. The separate public deployment keeps legal/support routes unpublished unless approved server-only content and versions are supplied.
- Local Compose describes PostgreSQL, Redis, Keycloak, an idempotent existing-volume realm reconciler, LocalStack, Mailpit, ClamAV, OpenTelemetry, and an optional API container. Terraform validates an encrypted state bootstrap plus account-guarded development networking/foundation resources.
- Docker Compose has started every local dependency and the API successfully; PostgreSQL V5 migration, V3-to-V4 and V4-to-V5 rehearsals, digest-pinned Testcontainers PostgreSQL transactions, existing-volume Keycloak email/SMTP reconciliation, API readiness, OIDC discovery, email capture, LocalStack health, and OpenTelemetry metrics have been exercised locally.
- A guarded one-command Android acceptance runner creates a separate Compose project with random ports and volumes plus a separate `com.kelimio.app.e2e` Android package, performs public Keycloak registration and Mailpit verification before S256 PKCE code exchange, drives the production mobile data/UI path through five Type-A and one Type-B answer plus sign-out, and proves cleanup reaches zero project containers, volumes, and networks while normal Compose container identities and ADB reverse mappings remain unchanged.
- GitHub workflows cover backend, mobile, contracts/generated drift, both web deployments, Terraform, secret scanning, dependency/filesystem scanning, runtime-image scanning, and CycloneDX SBOM retention. They are configured but have not run for this branch because the workflows intentionally trigger on pull requests or pushes to `main`; no pull request has been opened.

## Latest local verification

| Check | Result |
| --- | --- |
| Backend clean build on Java 21 with Docker Desktop | Passed; 89/89 tests passed, including 64 secure XLSX/parser/planner tests plus real-PostgreSQL V3-to-V4 and V4-to-V5 migration rehearsals, Type-B storage/API mapping, concurrent profile setup, onboarding/gating, identity non-linking, authoritative A/B vertical-slice, local mixed starter-release, and progress-projection transactions, with 0 skipped and 0 failed |
| Secure XLSX preview/parser/planner suite | Passed; 64/64 tests cover the exact reviewed workbook, immutable preview digests, deterministic/property allocation, language/grammar validation, package relationships, malicious XML/ZIP/content, hidden content, formulas, and resource ceilings |
| Docker Compose development stack | Passed; migration V5 applied without deleting the existing database, PostgreSQL, Redis, Keycloak, LocalStack, Mailpit, ClamAV, and the API reported healthy, the existing Keycloak volume was preserved, OpenTelemetry remained reachable, and API readiness returned 200 |
| Flutter formatting, analysis, and unit/widget tests | Passed; no analysis findings and 35/35 tests passed, including retry-stable/profile-session-isolated setup, cross-user progress-cache invalidation, stale-refresh/new-session races, fail-closed partial token persistence, bounded projection timeout/retry, Type-B protocol rejection, exact/overlapping marker checks, first-strong-character bidi layout, large-text wrapping, localized blank semantics, and an explicit v1-to-v2 local starter install path |
| Android API 36 emulator and debug application | Passed; WHPX acceleration available, cold boot completed, debug APK built and installed, and 5/5 checks passed in an isolated `com.kelimio.app.smoke` package across secure storage, recovery DB, auth restoration, and startup navigation without touching the normal app session |
| Isolated real registration-to-progress Android E2E | Passed; fresh Keycloak/PostgreSQL/Redis/LocalStack/Mailpit/API, verified email before token issuance, exact issuer/audience/nonce claims, provisional API gate, profile version 1, one enrollment, five Type-A plus one accessible Type-B shuffled question, deterministic Type-B idempotent replay, energy 5, pass 6/6, projected score 360/360 at version 7, sign-out/cache purge, zero isolated project containers/volumes/networks, exact test-image cleanup, and unchanged normal Compose container identities/ADB mappings |
| Contract schema tests, OpenAPI validation, and client regeneration | Passed; course/profile/question schema tests, exact and overlapping Type-B marker rejection, answer-key rejection, and 113 generated-client tests passed; the pinned generator validated the OpenAPI document and a second regeneration changed 0 of 148 tracked generated files |
| Admin web lint, typecheck, and production build | Passed locally |
| Public web lint, typecheck, production build, and unpublished-route release gates | Passed locally |
| Dependency, secret, and IaC/source security scans | Passed; workspace audits and Trivy found 0 high/critical vulnerability or misconfiguration findings, and Gitleaks found no leak across 400 source paths |
| Terraform 1.15.8 format/init/validate | Passed for bootstrap and development roots |
| Workflow/Dependabot YAML and PowerShell syntax | Passed; all 29 action references are immutable commits and the generator image is digest-pinned |

## Not yet verified or implemented

- Docker Desktop 4.84.0 and WSL 2 are installed and the local Compose acceptance path is verified. On this Windows host, backend test runs must export the active endpoint from `docker context inspect` as `DOCKER_HOST` so Testcontainers uses Docker Desktop's Linux engine; the root README includes the reproducible command.
- The Android API 36 SDK/emulator and Flutter 3.44 toolchain are installed and a debug APK has run successfully. iOS builds still require macOS/Xcode/CocoaPods, `mobile/ios/Podfile.lock` does not exist yet, and no signed AAB, IPA, TestFlight archive, or store artifact exists.
- The isolated automated auth flow obtains a genuine Keycloak Authorization Code + S256 PKCE token but injects that session at the mobile authentication interfaces. It does not exercise the native FlutterAppAuth Custom Tab, redirect/deep-link handoff, or persistent secure-token path; those remain native/staging acceptance work.
- No production Excel upload or teacher course-creation path exists yet. The secure parser/planner is an isolated preview core only: S3 quarantine, malware-scanner/worker execution, immutable source archive and provenance, approval binding, database schema/commit, authoring UI, publication, and reprojection remain absent. The local starter command supports only the bounded valid Type-A/Type-B workbook subset using English as its support language and does not masquerade as that import workflow.
- Published course metadata is currently frozen as a fail-closed interim rule while test/question release graphs are versioned; complete course-metadata revisioning and the reviewed Excel import transaction remain Phase 3 work.
- First-login profile setup now records explicit app/target/support language and time-zone choices. General profile editing and separate legal/child-safety consent facts are not implemented. The learner-course progress consumer exists, while profile-update, ranking, fraud, commerce, import, and operational DLQ/reprojection consumers remain open.
- Staging OIDC, AWS deployment, DNS/TLS, managed databases/cache/queues, WAF, observability operations, backups/restore, and GitHub deployment environments are absent.
- Question types C/D, offline practice, teacher authoring/release, purchases, ads, earnings/payout, moderation, privacy operations, complete admin tooling, and release hardening remain future phases.
- Legal text is not invented or published. Provider accounts, immutable app identifiers, store approvals, signing custody, and accountable operational owners require owner action.

## Immediate next milestone

Continue the next safe milestones while external release gates remain open:

1. retain the now-tested Excel preview core while adding its isolated upload/scanner/archive/approval boundary in Phase 3 without weakening the local starter-course boundary;
2. add privacy-safe Type-C typed cloze as the next student slice, then define and implement Type-D group scoring;
3. provision owner-approved staging AWS/OIDC/DNS/GitHub environments and run native registration-to-mobile-display acceptance;
4. build Android and iOS artifacts with the approved identifiers and platform toolchains.

The consolidated external decisions and accounts are in `docs/OWNER_ACTIONS.md`; launch-level gates remain in `docs/LAUNCH_BLOCKERS.md`. Provider-dependent functionality must stay disabled and fail closed until those actions are complete.

## Status update rule

Update this file when a phase exit gate changes, a blocker opens or closes, or release readiness changes. Every completed claim must link to code, automated evidence, an ADR, or an approved external record.
