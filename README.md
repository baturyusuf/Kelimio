# Kelimio

Kelimio is a multilingual language-learning and course-marketplace product. The intended production system includes a Flutter Android/iOS application, a Kotlin/Spring backend, internal administration and public legal web surfaces, versioned API contracts, and AWS infrastructure.

> Current state: Phase 0 foundations, a local/test-only secure Excel intake with an idempotent draft commit and explicit audited release activation, and a partial auth-to-answer vertical slice are implemented and locally buildable. The product is still **BLOCKED — external owner action required; NOT PUBLISH-READY** because production integrations, staging evidence, complete product flows, signed artifacts, and owner approvals are outstanding. See [status](docs/STATUS.md) and [launch blockers](docs/LAUNCH_BLOCKERS.md).

## Architecture baseline

- Mobile: Flutter 3.44.0 and its bundled Dart 3.12, Material 3, Riverpod, `go_router`, Drift/SQLite, Dio, and an OpenAPI-generated client.
- Backend: Kotlin 2.4.10 on Java 21, Spring Boot 3.5.16, imperative Spring MVC transactions, PostgreSQL, Redis, Flyway, jOOQ, and a transactional outbox foundation.
- Cloud: AWS by default; ECS Fargate for separate API and worker services, managed PostgreSQL, ElastiCache Redis, S3/CloudFront, SQS/DLQ, and EventBridge only for routing or schedules that need it.
- Web: Node.js 24 LTS and the stable Next.js 16.2 line for internal administration and public/legal pages.
- Infrastructure: Terraform 1.15.8, GitHub Actions OIDC, OpenTelemetry, least-privilege IAM, and managed secrets.

The system starts as a modular monolith. Kubernetes, Kafka, service mesh, OpenSearch, service-per-domain databases, global active-active data, and offline score synchronization are deferred until measurable adoption gates justify them.

## Repository layout

```text
backend/          Kotlin/Spring API and authoritative learning transaction
mobile/           Flutter Android/iOS student vertical slice
admin-web/        Closed internal-console deployment shell
public-web/       Publication-gated public, legal, support, and deletion routes
contracts/        OpenAPI source, schema tests, and generated Dart/TypeScript clients
infrastructure/   Local Compose services and Terraform bootstrap/foundation modules
docs/             Status, plans, ADRs, owner actions, blockers, and release controls
scripts/          Deterministic OpenAPI client-generation helper
.github/workflows Build, contract, infrastructure, security, and release gates
```

The checked-in applications contain no fake production repository or authentication fallback. Disabled provider-dependent surfaces fail closed.

## Local development

Prerequisites are the versions in [docs/VERSIONS.md], plus Docker Desktop for the local service stack and an Android SDK or macOS/Xcode for native mobile artifacts. Do not copy local credentials into staging or production.

Start the local dependencies and API:

```powershell
docker compose up -d
docker compose --profile app up --build
```

Prepare and start the repository's Android 16 / API 36 development emulator:

```powershell
.\scripts\android-emulator.cmd -Action setup
.\scripts\android-emulator.cmd -Action start
```

The script creates `kelimio_api36`, a Pixel 7 profile with Google APIs but no
Play Store. It uses a cold boot to avoid host snapshot incompatibilities and
reverses ports `4566`, `8080`, and `8081`, so the emulator can reach LocalStack,
the local API, and the OIDC provider through `localhost`. Check or stop it with
`-Action status` and
`-Action stop`. The `.cmd` launcher applies a process-only PowerShell execution
policy and does not change the workstation's persistent security settings.
Google Play Console access is not required for this emulator.

Run the repository's sequential Android API/device smoke matrix with:

```powershell
.\scripts\android-device-matrix.cmd -Headless
```

The guarded runner covers API 24/Nexus 5, API 30/Pixel 3a, and API 36/Pixel 7
with five isolated storage, recovery, and startup checks per profile. It creates
only the allowlisted repository AVDs, never deletes or wipes an AVD, and restores
the originally running Kelimio emulator and its ADB mappings. See
[`docs/ANDROID_DEVICE_MATRIX.md`](docs/ANDROID_DEVICE_MATRIX.md) for exact scope,
the optional endpoint E2E command, and the release gates this evidence does not
close.

Keycloak is available at `http://localhost:8081`, the API at `http://localhost:8080`, Mailpit at `http://localhost:8025`, and LocalStack at `http://localhost:4566`. The realm has no demo user. Register through OIDC, verify the captured message in Mailpit on a fresh realm, and complete the in-app profile setup. When local development tools are enabled, an authenticated and profile-complete user can explicitly install the immutable reviewed mixed Type-A/Type-B/Type-C/Type-D starter course, including when an older local starter is already present. Starter release v4 contains five Type-A questions, one Type-B question, the exact reviewed-workbook Type-C row, and one four-pair Type-D question from the unambiguous `EV` group (`Pencere`/`Window`, `Kapı`/`Door`, `Masa`/`Table`, and `Sandalye`/`Chair`). This is bounded local test content using English as its support language; it creates no learning results and does not enable production import.

The local/test-only course-import intake accepts an owner-scoped, checksum-bound multipart upload through presigned S3 requests, dispatches it through an SQS/DLQ-backed worker, scans it with network-isolated ClamAV, persists immutable source/report provenance, exposes bounded preview and issue pages, and records approval against one exact preview binding. `xlsx-v2` applies deterministic test allocation first and then composes only complete two-to-six-row matching groups inside one test. For the reviewed workbook, 23 source rows become 14 runtime questions, including three Type-D questions and 12 matching pairs, with every source row preserved exactly once. A separate idempotent commit creates exactly one `DRAFT` course, committed initial change set, complete immutable `DRAFT` release hierarchy, reviewed Type-B options, and stable multilingual Type-A options with no active release, enrollment, entitlement, catalog visibility, or publication. Matching releases carry the stored `question.matching.v1` requirement; catalog and direct learning endpoints fail closed for clients that do not advertise it. An owner-scoped impact preview and optimistic binding then guard a separate atomic local/test activation, append-only publication fact/outbox event, and paged release-aware progress reprojection job. With local tools enabled, the Flutter **Teacher** tab selects one `.xlsx`, performs the checksum-bound upload, pages preview/issues, and keeps preview approval, draft creation, and publication behind three separate confirmations. Existing V9 previews without the versioned settings snapshot remain approval-only. Staging and production remain fail closed until author eligibility, consent, least-privilege runtime identities, retention, complete authoring/conflict recovery, rollback/reprojection evidence with existing learners, and operational controls are complete.

Run the backend checks:

```powershell
$env:DOCKER_HOST = (docker context inspect --format '{{.Endpoints.docker.Host}}').Trim()
cd backend
.\gradlew.bat clean build
```

The explicit Docker endpoint keeps Testcontainers on Docker Desktop's active
engine instead of silently skipping the real-PostgreSQL integration test.

Run the isolated real-service Excel intake acceptance flow with:

```powershell
.\scripts\local-import-e2e.cmd
```

The guarded runner creates a randomly named Compose project and disposable
ports, networks, volumes, users, and secrets. It exercises the exact reviewed
workbook through upload, malware scan, preview, ownership checks, approval, an
idempotent unpublished-draft commit, impact binding, and explicit initial
publication; also verifies clean-invalid and EICAR rejection paths, queue drain,
immutable hierarchy/provenance, runtime options, source lineage, capability
gating, activation/outbox facts, and reprojection completion. The draft boundary
is checked before activation and creates no active/public or enrollment side
effects. It then removes only its
validated isolated resources and confirms that the normal Compose containers
were unchanged. Neither an AWS account nor Google Play Console is needed for
this local acceptance flow.

Generate clients and run the mobile checks:

```powershell
.\scripts\generate-clients.ps1
cd mobile
flutter pub get --enforce-lockfile
flutter gen-l10n
dart format --set-exit-if-changed lib test integration_test
flutter analyze --fatal-infos
flutter test
```

Run the debug application on the local emulator after the Compose stack is
healthy:

```powershell
cd mobile
flutter run -d emulator-5554 `
  --flavor production `
  --dart-define=KELIMIO_API_BASE_URL=http://localhost:8080 `
  --dart-define=KELIMIO_OIDC_ISSUER=http://localhost:8081/realms/kelimio `
  --dart-define=KELIMIO_OIDC_CLIENT_ID=kelimio-mobile `
  --dart-define=KELIMIO_LOCAL_DEVELOPMENT_TOOLS=true

flutter test integration_test -d emulator-5554 `
  --flavor smoke `
  --dart-define=KELIMIO_API_BASE_URL=http://localhost:8080 `
  --dart-define=KELIMIO_OIDC_ISSUER=http://localhost:8081/realms/kelimio `
  --dart-define=KELIMIO_OIDC_CLIENT_ID=kelimio-mobile `
  --dart-define=KELIMIO_OIDC_REDIRECT_URI=com.kelimio.app.smoke:/oauthredirect `
  --dart-define=KELIMIO_OIDC_POST_LOGOUT_REDIRECT_URI=com.kelimio.app.smoke:/logout `
  --dart-define=KELIMIO_ISOLATED_DEVICE_TEST_STORAGE=true `
  --dart-define=KELIMIO_LOCAL_DEVELOPMENT_TOOLS=true
```

Ordinary device tests use the separate `com.kelimio.app.smoke` package and may
reset only that package's test storage. They do not read, overwrite, or delete
the normal `com.kelimio.app` session.

Run the complete real local acceptance journey with one command after the
emulator is ready (the normal Compose stack may remain running):

```powershell
.\scripts\local-android-e2e.cmd
```

This runner creates a randomly named Compose project with separate ports,
network, and volumes; registers a random user through Keycloak's public form;
verifies the Mailpit message; exchanges a real Authorization Code + S256 PKCE
code; and drives the production Flutter repositories, controllers, Drift store,
and UI through profile setup, enrollment, eight answers, Type-B replay,
Type-C replay/reconciliation, Type-D matching replay/reconciliation, projection,
the native **Teacher** workbook selector, checksum-bound multipart upload,
malware scan, paged preview, three explicit approval/draft/publication gates,
initial release activation, catalog return, and sign-out. The guarded run boots
a fresh Flyway V12 stack with a per-run
random 32-byte matching-replay key, passes 8/8 with 480/480 projected score at
projection version 9, rejects a changed matching edge without mutation, purges
private state, and verifies isolated cleanup. Random credentials and the replay
key are generated at runtime, remain limited to the isolated run, and are never
printed or written to the repository;
the runner restores its process environment and deletes temporary service/app
state during guarded cleanup. The Android build uses the separate
`com.kelimio.app.e2e` application ID, so it cannot overwrite the normal app's
Drift or secure-storage state. The runner deletes its validated project resources
and exact test images, restores its own ADB mappings, then verifies that the
normal Compose container identities and reverse mappings are unchanged.

The automated test injects the genuine Keycloak session after completing the
protocol flow, so it does not claim coverage of the native FlutterAppAuth Custom
Tab/deep-link presentation. That remains a separate native/staging release gate.

Each Node workspace uses its committed `pnpm-lock.yaml`:

```powershell
cd contracts
pnpm install --frozen-lockfile
pnpm test

cd ..\admin-web
pnpm install --frozen-lockfile
pnpm lint
pnpm typecheck
pnpm build

cd ..\public-web
pnpm install --frozen-lockfile
pnpm lint
pnpm typecheck
pnpm build
pnpm test:release-gates
```

The repository pins Node.js 24.18.0. Checks run on the currently available
24.14.0 host do not close the exact-version gate; CI or another matching host
must repeat them with 24.18.0.

See [backend configuration](backend/README.md), [local infrastructure notes](infrastructure/local/README.md), [contract generation](contracts/README.md), [mobile configuration](mobile/README.md), and [Terraform usage](infrastructure/terraform/README.md) for environment-specific details.

## Product truth that shapes the code

- Application locale, course target language, and course support language are independent.
- Excel creates a course once; later content changes are made through mobile teacher authoring.
- Online learning is server-authoritative. Signed offline packages provide scoreless practice and never sync answer history.
- Online Type-C typed answers are graded by the backend under a pinned language policy. Raw or canonical learner text is never retained in PostgreSQL, logs, analytics, outbox events, or mobile recovery state; lost-response recovery uses an ownership-scoped committed-result lookup.
- Online Type-D matching sends independently ordered target/support arrays before an answer, accepts one complete bijection, and grades it all-or-nothing under the attempt's pinned support language. Submitted/correct mappings never enter durable mobile recovery. A durable matching answer fact contains no explicit mapping or correct-pair count: it retains a random salt, an HMAC-SHA-256 equality token, its key version, and the required authoritative `is_correct` fact; authored correct relationships remain in immutable content tables. The staging/production secret keyring remains outside PostgreSQL, source, logs, outbox events, and diagnostics; version-specific replay uses constant-time comparison. This protects against candidate testing from a database-only compromise while the external key remains secret; it is not anonymity or full-compromise protection. Correctness necessarily leaks limited information: `true` identifies the authored mapping, and with exactly two pairs `false` identifies the sole swapped mapping. The only client/API responses that may contain the explicit post-commit correct mapping are the no-store submission and ownership-scoped reconciliation responses. The checked-in Compose key is public and local-only; staging and production must inject their own retained versioned keyring from AWS Secrets Manager and fail closed when it is absent or invalid.
- Question/test content is immutable and release-based. Active progress can be reprojected; lifetime score never falls because a teacher edited content.
- Free-course energy, rewarded ads, store purchases, course entitlements, teacher earnings, and payouts require auditable server-side flows.

See [ADR-000](docs/adr/ADR-000-source-of-truth.md) for source priority and normalized contradictions.

## Delivery roadmap

The implementation sequence is maintained in [docs/IMPLEMENTATION_PLAN.md]. The first local executable milestone below is implemented; its staging exit gate remains open:

```text
OIDC sign-in -> course read/enroll -> one online question ->
authoritative answer transaction -> score/energy ledger -> Flutter display
```

No milestone is complete without its contract, migration, tests, telemetry, and failure behavior.

## Governance and release

- [Current status](docs/STATUS.md)
- [Implementation plan](docs/IMPLEMENTATION_PLAN.md)
- [Owner actions](docs/OWNER_ACTIONS.md)
- [Launch blockers](docs/LAUNCH_BLOCKERS.md)
- [Release checklist](docs/RELEASE_CHECKLIST.md)
- [Pinned versions](docs/VERSIONS.md)
- [Architecture decisions](docs/adr/)

Do not commit secrets. Do not send secrets through chat. Do not mark the repository publish-ready until every required release gate has objective evidence.
