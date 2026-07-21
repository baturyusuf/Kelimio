# Kelimio

Kelimio is a multilingual language-learning and course-marketplace product. The intended production system includes a Flutter Android/iOS application, a Kotlin/Spring backend, internal administration and public legal web surfaces, versioned API contracts, and AWS infrastructure.

> Current state: Phase 0 foundations and a partial auth-to-answer vertical slice are implemented and locally buildable. The product is still **BLOCKED — external owner action required; NOT PUBLISH-READY** because production integrations, staging evidence, complete product flows, signed artifacts, and owner approvals are outstanding. See [status](docs/STATUS.md) and [launch blockers](docs/LAUNCH_BLOCKERS.md).

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

Keycloak is available at `http://localhost:8081`, the API at `http://localhost:8080`, Mailpit at `http://localhost:8025`, and LocalStack at `http://localhost:4566`. The realm has no demo user. Register through OIDC; do not seed fake learning results. The course-import workflow is not implemented yet, so a complete manual learner journey still requires real course data to be inserted by a future supported path.

Run the backend checks:

```powershell
cd backend
.\gradlew.bat clean build
```

Generate clients and run the mobile checks:

```powershell
.\scripts\generate-clients.ps1
cd mobile
flutter pub get --enforce-lockfile
flutter gen-l10n
flutter analyze --fatal-infos
flutter test
```

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

See [backend configuration](backend/README.md), [local infrastructure notes](infrastructure/local/README.md), [contract generation](contracts/README.md), [mobile configuration](mobile/README.md), and [Terraform usage](infrastructure/terraform/README.md) for environment-specific details.

## Product truth that shapes the code

- Application locale, course target language, and course support language are independent.
- Excel creates a course once; later content changes are made through mobile teacher authoring.
- Online learning is server-authoritative. Signed offline packages provide scoreless practice and never sync answer history.
- Question/test content is immutable and release-based. Active progress can be reprojected; lifetime score never falls because a teacher edited content.
- Free-course energy, rewarded ads, store purchases, course entitlements, teacher earnings, and payouts require auditable server-side flows.

See [ADR-000](docs/adr/ADR-000-source-of-truth.md) for source priority and normalized contradictions.

## Delivery roadmap

The implementation sequence is maintained in [docs/IMPLEMENTATION_PLAN.md]. The first executable milestone is a real vertical slice:

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
