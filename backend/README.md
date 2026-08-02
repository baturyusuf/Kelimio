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
KELIMIO_MATCHING_REPLAY_ACTIVE_KEY_VERSION=<canonical-active-version>
KELIMIO_MATCHING_REPLAY_KEYS=<version>=<base64-encoded-32-byte-key>[,...]
```

When the local/test-only import intake is enabled, the API and worker run as
separate `KELIMIO_RUNTIME_ROLE=api|worker` processes. Both require the S3 bucket
and SQS/DLQ names plus approved local/test endpoints; only the API receives the
OIDC settings, matching-replay key ring, cursor HMAC key, and S3 presigner. Only
the worker receives SQS polling and private ClamAV network access, runs without
an HTTP server, and has Flyway disabled. The root Compose file supplies isolated
local defaults. Do not reuse those public values or the shared local database
role outside local development.

`KELIMIO_OIDC_JWK_SET_URI` is optional for a private network path to the same
issuer's keys; issuer and audience validation still apply. Never commit a real
database password, client secret, access token, or provider credential.
Only the explicit `local` environment permits HTTP OIDC endpoints; test,
development, staging, and production fail startup unless issuer/key endpoints
use HTTPS.

Matching replay configuration is mandatory in every environment. Versions use
one to 32 lowercase ASCII letters, digits, `.`, `_`, or `-`; the first character
must be alphanumeric. The comma-separated key ring must contain the active
version exactly once, is limited to eight unique versions, and every value must
Base64-decode to exactly 32 bytes. Missing or invalid configuration fails
startup. Keep real values in the environment's secret store; the Compose default
is an intentionally public local-only test key. A retired verification key must
remain in the ring while any fact bearing its version is replayable. Before a
ninth version is needed, accept a new ADR and migration/key-provider design
rather than deleting a still-required key or weakening replay behavior.

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
Type-A/Type-B/Type-C/Type-D course using English as its support language.
Immutable starter release v4 contains five Type-A questions, one Type-B
question, the exact reviewed Type-C row, and one four-pair Type-D question from
the reviewed `EV` group. The route returns not found outside enabled local mode
and is separate from the production import core described below.

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

## Matching boundary

Flyway V7 adds immutable Type-D pair/translation content and pins the active
enrollment support language onto each attempt. Flyway V8 hardens matching replay
evidence before release: it rejects an upgrade containing an existing unkeyed
matching fact, removes the revealing correct-pair count, and adds the replay-key
version. Before submission, a matching question has a required null prompt, no
options, and independently ordered `targetItems` and `supportItems`; no pair
identity or correlated ordering field is public.

The answer endpoint accepts exactly one complete two-to-six-item bijection and
grades the whole question all-or-nothing inside the existing authoritative
answer transaction. Duplicate, foreign, incomplete, or cross-side-overlapping
IDs fail with `422` before score, energy, answer, attempt, or outbox facts are
written. Reordered retries compare an identity-bound, key-version-bound salted
HMAC-SHA-256 token in constant time. PostgreSQL retains only the non-secret salt,
HMAC token, key version, and unavoidable question-level `is_correct` fact—not
the submitted mapping or a correct-pair count—while the HMAC key remains outside
the database. This token protects equality replay against database-only offline
enumeration; it is not anonymity or full-compromise protection. A true
`is_correct` necessarily identifies the submitted mapping as the authored one;
for a two-item complete bijection, a false value identifies the only swapped
mapping. Both are unavoidable consequences of retaining authoritative
correctness.
One wrong mapping can debit at most one energy unit. The only client/API
responses that may contain the correct mapping are no-store post-commit feedback
and the ownership-scoped no-store reconciliation response; request, feedback,
domain, and persistence diagnostics
redact mapping evidence and key metadata.

This local runtime does not authorize production workbook matching conversion.
That path remains fail-closed until group allocation semantics and a stored
minimum-client/capability gate are implemented and verified.

## Secure Excel intake and unpublished draft commit

Flyway V9 and the local/test API/worker boundary implement the owner-scoped
intake and approval lifecycle for the reviewed XLSX format. Creation binds the filename,
media type, total size, whole-file SHA-256, fixed multipart plan, and per-part
checksums. The API returns short-lived presigned S3 part requests, verifies the
exact completed object version, and appends the processing request through the
transactional outbox. The worker claims a bounded lease, streams the versioned
quarantine object through a network-isolated ClamAV process, archives an
immutable source and validation report, and invokes the existing fail-closed
ZIP/XML parser and deterministic planner. Formula, hidden, active, external,
unsupported, incomplete, ambiguous, oversized, stale, or identity-changing
content fails closed.

Status, preview, issue, and approval responses are owner-scoped and `no-store`;
opaque page cursors are HMAC-bound to the owner, import, immutable preview, and
scope. Approval appends one exact provenance/digest binding and still has no
course side effect. Flyway V10 adds a separate idempotent commit that consumes
only a versioned `import-content-v1` preview and creates exactly one `DRAFT`
course, committed initial change set, and immutable `DRAFT` release hierarchy.
It preserves every row, hierarchy position, translation, authored distractor,
and matching-group source value, while creating no active release, runtime
options, enrollment, entitlement, or publication. Staging and production
imports fail startup until the outstanding author-eligibility, consent,
separate least-privilege database/runtime identities, retention/Object
Lock/KMS, Type-D conversion/capability, publication, and operational gates are
implemented and approved.

Run the focused evidence with:

```powershell
.\gradlew.bat test --tests "com.kelimio.api.importpipeline.*" --no-daemon
```

From the repository root, run the isolated real PostgreSQL/S3/SQS/ClamAV/OIDC
acceptance journey with:

```powershell
.\scripts\local-import-e2e.cmd
```

It verifies valid approval and idempotent draft commit, clean-invalid
validation, EICAR rejection, cross-owner denial, queue drain, immutable
hierarchy/evidence, and zero active/public/enrollment side effects without using
AWS or Google Play accounts.

## Verification

```powershell
.\gradlew.bat clean build
```

The current backend checks include V7 content/language and V8 matching migration
evidence; V10 empty-database and retained upgrade rehearsal; import intake,
approval, idempotent draft commit, lease, retry, transition, ownership,
artifact, hierarchy, and security invariants;
HMAC key-ring and fail-closed configuration tests; matching privacy/order/replay
tests; real-PostgreSQL authoritative answer flows; support-language pinning; and
local starter v4 multi-user installation. The complete unskipped backend run passes
34 suites and 167/167 tests.

The vertical-slice integration test uses Testcontainers and a real PostgreSQL
image. It is explicitly skipped when Docker is unavailable; a green build with
that skip is not database-runtime or staging evidence.
