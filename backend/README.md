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
returns not found outside enabled local mode. Full multi-language Excel import
and unsupported question types remain blocked rather than being discarded.

## Verification

```powershell
.\gradlew.bat clean build
```

The vertical-slice integration test uses Testcontainers and a real PostgreSQL
image. It is explicitly skipped when Docker is unavailable; a green build with
that skip is not database-runtime or staging evidence.
