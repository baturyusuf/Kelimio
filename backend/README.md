# Kelimio backend

Kotlin/Spring Boot API for the first server-authoritative learning slice. The
service validates JWTs from an external OIDC issuer and uses PostgreSQL as its
only durable truth. It has no demo identity, in-memory repository, or production
fallback.

## Required configuration

```text
KELIMIO_DB_URL=jdbc:postgresql://localhost:5432/kelimio
KELIMIO_DB_USER=kelimio
KELIMIO_DB_PASSWORD=<local-or-secret-store-value>
KELIMIO_ENVIRONMENT=local
KELIMIO_OIDC_ISSUER=http://localhost:8081/realms/kelimio
KELIMIO_OIDC_AUDIENCE=kelimio-api
```

`KELIMIO_OIDC_JWK_SET_URI` is optional for a private network path to the same
issuer's keys; issuer and audience validation still apply. Never commit a real
database password, client secret, access token, or provider credential.
Only the explicit `local` environment permits HTTP OIDC endpoints; test,
development, staging, and production fail startup unless issuer/key endpoints
use HTTPS.

The root Compose stack supplies local-only values. After its dependencies are
healthy, run the API directly with:

```powershell
.\gradlew.bat bootRun
```

Flyway applies the schema on startup. Readiness is exposed at
`/actuator/health/readiness`; application routes require a valid bearer token.
No course or user is seeded on startup. When Compose explicitly enables
`KELIMIO_LOCAL_STARTER_COURSE_ENABLED`, an authenticated local user can invoke
`POST /v1/development/starter-course` to install one idempotent immutable
Type-A course derived from the reviewed workbook's English subset. The route
returns not found outside enabled local mode and is separate from the import
core described below.

## Secure Excel preview core

The backend contains an isolated, side-effect-free core for the reviewed XLSX
format. It snapshots the input, applies bounded ZIP/XML and relationship
preflight checks, streams visible inert cells, normalizes the multilingual
workbook grammar, deterministically allocates tests, and produces versioned
allocation and complete-preview SHA-256 digests. Formula, hidden, active,
external, unsupported, incomplete, or ambiguous content fails closed.

This is not a production import endpoint. It has no S3 quarantine/scanner
worker, immutable archive/provenance approval, database commit, course-release,
or teacher-authoring side effect. Those Phase 3 gates remain open.

Run the focused evidence with:

```powershell
.\gradlew.bat test --tests "com.kelimio.api.importpipeline.*" --no-daemon
```

## Verification

```powershell
.\gradlew.bat clean build
```

The vertical-slice integration test uses Testcontainers and a real PostgreSQL
image. It is explicitly skipped when Docker is unavailable; a green build with
that skip is not database-runtime or staging evidence.
