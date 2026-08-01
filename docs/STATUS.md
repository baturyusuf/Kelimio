# Project Status

Last updated: 2026-08-01

## Overall status

**BLOCKED — external owner action required; NOT PUBLISH-READY**

Kelimio now has a locally buildable Phase 0 foundation, a healthy Docker-backed development stack, a verified Android debug runtime, and a partial Phase 1 auth-to-answer implementation. This is engineering progress, not a release: there is no deployed staging or production environment, no production-signed store artifact exists, and the owner/provider/legal gates remain open.

## Current phase

| Area | State | Evidence or next gate |
| --- | --- | --- |
| Source review and conflict register | Complete | `docs/adr/ADR-000-source-of-truth.md` |
| Governance foundation | Complete | Root guidance and `docs/` control documents |
| Version and supply-chain baseline | Implemented with one native-platform gap | Modern Gradle wrappers, non-CocoaPods lockfiles, exact runtime pins, immutable CI action SHAs, generator image digest, and image SBOM/scan steps exist; `ios/Podfile.lock` still requires a macOS run |
| Monorepo application scaffold | Implemented; Phase 0 remains open | Backend, mobile, two web deployments, contracts, local services, Terraform, and CI exist and pass the available static/build checks |
| Real auth-to-answer vertical slice | Partial; Phase 1 in progress | OIDC resource server/mobile PKCE adapter, catalog, enrollment, Type-A attempt, idempotent answer, score/energy facts, outbox write, and Flutter display exist; staging E2E, explicit onboarding, and projection worker do not |
| Student product | Not started beyond the first slice | Phase 2 exit gate |
| Teacher import and authoring | Source plan reviewed; implementation not started | Phase 3 exit gate; the supplied workbook is normalized as design input only |
| Commerce, ads, earnings, and payout | Not started | Phase 4 exit gate and owner/provider actions |
| Admin, infrastructure, and operations | Foundation only | Admin fails closed; Terraform currently covers bootstrap/network/foundation, not a production environment |
| Hardening and store release | Not started | Phase 6 and `docs/RELEASE_CHECKLIST.md` |

## Implemented evidence

- `contracts/openapi/kelimio-api.yaml` keeps attempt payloads answer-key-free and accepts no client-owned score, energy, entitlement, or user identity. Under ADR-000, only the response after an answer is committed reveals that submitted question's correct option for feedback.
- The generation script produces checked-in Dart/Dio and TypeScript clients with a pinned OpenAPI Generator; schema tests cover valid responses, required properties, closed objects, and canonical language tags.
- The Kotlin/Spring API has Flyway schema, real JWT validation, catalog/enrollment/attempt endpoints, persistent idempotency, authoritative scoring and free-course energy rules, release-pinned manifests, cross-checked append-only facts, and transactional outbox writes.
- The Flutter client uses the generated API client, AppAuth, secure token storage, Riverpod, `go_router`, Dio, Drift recovery state, private-state purge on session changes, distinct authentication/authorization failures, Turkish/English/Arabic localization, and RTL-aware UI.
- The repository-managed Android API 36 emulator cold-boots without Google Play, maps the local API/OIDC ports through ADB, and has exercised secure storage, the Drift recovery database, session restoration, and signed-out startup on a real Android runtime.
- The internal admin deployment always returns not found until server-side OIDC, MFA, RBAC, and audit exist. The separate public deployment keeps legal/support routes unpublished unless approved server-only content and versions are supplied.
- Local Compose describes PostgreSQL, Redis, Keycloak, LocalStack, Mailpit, ClamAV, OpenTelemetry, and an optional API container. Terraform validates an encrypted state bootstrap plus account-guarded development networking/foundation resources.
- Docker Compose has started every local dependency and the API successfully; PostgreSQL migrations, the digest-pinned Testcontainers PostgreSQL transaction, API readiness, OIDC discovery, email capture, LocalStack health, and OpenTelemetry metrics have been exercised locally.
- GitHub workflows cover backend, mobile, contracts/generated drift, both web deployments, Terraform, secret scanning, dependency/filesystem scanning, runtime-image scanning, and CycloneDX SBOM retention. They are configured but have not yet run on GitHub for this uncommitted branch.

## Latest local verification

| Check | Result |
| --- | --- |
| Backend clean build on Java 21 with Docker Desktop | Passed; 16/16 tests passed, including the real-PostgreSQL vertical-slice transaction, with 0 skipped and 0 failed |
| Docker Compose development stack | Passed; PostgreSQL, Redis, Keycloak, LocalStack, Mailpit, ClamAV, and the API reported healthy, OpenTelemetry was reachable, and all five HTTP readiness/discovery endpoints returned 200 |
| Flutter formatting, analysis, and unit/widget tests | Passed; 48 source/test files formatted, no analysis findings, 14/14 tests passed |
| Android API 36 emulator and debug application | Passed; WHPX acceleration available, cold boot completed, debug APK built and installed, and 5/5 device integration checks passed across secure storage, recovery DB, auth restoration, and startup navigation |
| Contract schema tests, OpenAPI lint, and client regeneration | Passed; two consecutive formatted generations produced the same 129-file manifest |
| Admin web lint, typecheck, and production build | Passed locally |
| Public web lint, typecheck, production build, and unpublished-route release gates | Passed locally |
| Dependency, secret, and IaC/source security scans | Passed; workspace audits and Trivy found 0 high/critical vulnerability or misconfiguration findings, and Gitleaks found no leak across 400 source paths |
| Terraform 1.15.8 format/init/validate | Passed for bootstrap and development roots |
| Workflow/Dependabot YAML and PowerShell syntax | Passed; all 29 action references are immutable commits and the generator image is digest-pinned |

## Not yet verified or implemented

- Docker Desktop 4.84.0 and WSL 2 are installed and the local Compose acceptance path is verified. On this Windows host, backend test runs must export the active endpoint from `docker context inspect` as `DOCKER_HOST` so Testcontainers uses Docker Desktop's Linux engine; the root README includes the reproducible command.
- The Android API 36 SDK/emulator and Flutter 3.44 toolchain are installed and a debug APK has run successfully. iOS builds still require macOS/Xcode/CocoaPods, `mobile/ios/Podfile.lock` does not exist yet, and no signed AAB, IPA, TestFlight archive, or store artifact exists.
- No supported Excel import/course creation path exists yet; the current end-to-end integration test creates controlled database fixtures.
- Published course metadata is currently frozen as a fail-closed interim rule while test/question release graphs are versioned; complete course-metadata revisioning and the reviewed Excel import transaction remain Phase 3 work.
- First-login profile defaults still need an explicit onboarding/update flow, and the outbox has no worker/projection consumer yet.
- Staging OIDC, AWS deployment, DNS/TLS, managed databases/cache/queues, WAF, observability operations, backups/restore, and GitHub deployment environments are absent.
- Question types B/C/D, offline practice, teacher authoring/release, purchases, ads, earnings/payout, moderation, privacy operations, complete admin tooling, and release hardening remain future phases.
- Legal text is not invented or published. Provider accounts, immutable app identifiers, store approvals, signing custody, and accountable operational owners require owner action.

## Immediate next milestone

Close the remaining Phase 0 and Phase 1 proof gaps:

1. implement explicit profile/language onboarding and the outbox projection worker;
2. implement a supported course creation/import seed path, then execute the full local learner journey;
3. provision owner-approved staging AWS/OIDC/DNS/GitHub environments and run the real registration-to-mobile-display acceptance test;
4. build Android and iOS artifacts with the approved identifiers and platform toolchains.

The consolidated external decisions and accounts are in `docs/OWNER_ACTIONS.md`; launch-level gates remain in `docs/LAUNCH_BLOCKERS.md`. Provider-dependent functionality must stay disabled and fail closed until those actions are complete.

## Status update rule

Update this file when a phase exit gate changes, a blocker opens or closes, or release readiness changes. Every completed claim must link to code, automated evidence, an ADR, or an approved external record.
