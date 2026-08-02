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
`POST /v1/development/starter-course` to install one idempotent immutable mixed
Type-A/Type-B/Type-C course derived from the reviewed workbook subset using
English as its support language. Immutable starter release v3 contains five
Type-A questions, one Type-B question, and the exact reviewed Type-C row. The
route returns not found outside enabled local mode and is separate from the
import core described below.

## Typed-cloze boundary

Type-C correctness is derived inside the authoritative answer transaction from
the attempt's pinned immutable revision and `typed-answer-v1` target-language
policy. The answer endpoint enforces an 8192-byte body limit before Jackson,
authentication, or transactional/idempotency work. Its pre-Jackson matcher uses
Spring MVC path-pattern semantics, so matrix parameters and percent-encoded path
literals cannot bypass the cap; declared and chunked oversize bodies receive a
generic no-store `413` response. Locale-independent raw-envelope validation also
runs before the transaction, while locale-pinned normalization and grading stay
inside it.

Typed answer facts retain only salted replay evidence and a match ordinal. Raw
or canonical learner text is never persisted, logged, emitted to analytics or
the outbox, or returned through recovery. An ownership-scoped no-store recorded-
answer lookup supports lost-response reconciliation without exposing whether
another user owns a submission. Primary correct-answer text is returned only in
transaction-specific post-commit feedback; diagnostic string representations
redact it.

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
