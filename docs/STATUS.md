# Project Status

Last updated: 2026-07-21

## Overall status

**BLOCKED — external owner action required; NOT PUBLISH-READY**

Kelimio now has a locally buildable Phase 0 foundation and a partial Phase 1 auth-to-answer implementation. This is engineering progress, not a release: there is no deployed staging or production environment, the Docker-backed PostgreSQL acceptance path has not run on this workstation, native mobile artifacts have not been built, and the owner/provider/legal gates remain open.

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
- The internal admin deployment always returns not found until server-side OIDC, MFA, RBAC, and audit exist. The separate public deployment keeps legal/support routes unpublished unless approved server-only content and versions are supplied.
- Local Compose describes PostgreSQL, Redis, Keycloak, LocalStack, Mailpit, ClamAV, OpenTelemetry, and an optional API container. Terraform validates an encrypted state bootstrap plus account-guarded development networking/foundation resources.
- GitHub workflows cover backend, mobile, contracts/generated drift, both web deployments, Terraform, secret scanning, dependency/filesystem scanning, runtime-image scanning, and CycloneDX SBOM retention. They are configured but have not yet run on GitHub for this uncommitted branch.

## Latest local verification

| Check | Result |
| --- | --- |
| Backend clean build on Java 21 | Passed; 16 tests, 15 passed, 1 skipped because Docker is unavailable, 0 failed |
| Flutter formatting, analysis, and tests | Passed; 110 files unchanged, no analysis findings, 14/14 tests passed |
| Contract schema tests, OpenAPI lint, and client regeneration | Passed; two consecutive formatted generations produced the same 129-file manifest |
| Admin web lint, typecheck, and production build | Passed locally |
| Public web lint, typecheck, production build, and unpublished-route release gates | Passed locally |
| Dependency, secret, and IaC/source security scans | Passed; workspace audits and Trivy found 0 high/critical vulnerability or misconfiguration findings, and Gitleaks found no leak across 400 source paths |
| Terraform 1.15.8 format/init/validate | Passed for bootstrap and development roots |
| Workflow/Dependabot YAML and PowerShell syntax | Passed; all 29 action references are immutable commits and the generator image is digest-pinned |

## Not yet verified or implemented

- Docker is unavailable on this workstation, so Compose runtime health, Flyway against the real PostgreSQL container, the Testcontainers vertical-slice transaction, and the backend container image remain unverified locally.
- Android SDK is absent and iOS builds require macOS/Xcode/CocoaPods. `mobile/ios/Podfile.lock` does not exist yet; no signed AAB, IPA, TestFlight archive, or store artifact exists.
- No supported Excel import/course creation path exists yet; the current end-to-end integration test creates controlled database fixtures.
- Published course metadata is currently frozen as a fail-closed interim rule while test/question release graphs are versioned; complete course-metadata revisioning and the reviewed Excel import transaction remain Phase 3 work.
- First-login profile defaults still need an explicit onboarding/update flow, and the outbox has no worker/projection consumer yet.
- Staging OIDC, AWS deployment, DNS/TLS, managed databases/cache/queues, WAF, observability operations, backups/restore, and GitHub deployment environments are absent.
- Question types B/C/D, offline practice, teacher authoring/release, purchases, ads, earnings/payout, moderation, privacy operations, complete admin tooling, and release hardening remain future phases.
- Legal text is not invented or published. Provider accounts, immutable app identifiers, store approvals, signing custody, and accountable operational owners require owner action.

## Immediate next milestone

Close the remaining Phase 0 and Phase 1 proof gaps:

1. run the Compose and Testcontainers suites on a Docker-capable host and retain the migration/transaction evidence;
2. implement explicit profile/language onboarding and the outbox projection worker;
3. implement a supported course creation/import seed path, then execute the full local learner journey;
4. provision owner-approved staging AWS/OIDC/DNS/GitHub environments and run the real registration-to-mobile-display acceptance test;
5. build Android and iOS artifacts with the approved identifiers and platform toolchains.

The consolidated external decisions and accounts are in `docs/OWNER_ACTIONS.md`; launch-level gates remain in `docs/LAUNCH_BLOCKERS.md`. Provider-dependent functionality must stay disabled and fail closed until those actions are complete.

## Status update rule

Update this file when a phase exit gate changes, a blocker opens or closes, or release readiness changes. Every completed claim must link to code, automated evidence, an ADR, or an approved external record.
