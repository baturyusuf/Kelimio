# API contracts

`openapi/kelimio-api.yaml` is the versioned source of truth for external REST
clients. Backend controller changes and generated clients must pass a contract
drift check in CI.

The contract intentionally covers only implemented or actively verified
vertical slices. It
contains no answer keys in attempt payloads and no client-supplied user, score,
energy, or entitlement claims. Type A and Type B carry four options; Type C
(`TYPED_CLOZE`) carries none and requires exactly one literal `---`; Type D
(`MATCHING`) exposes independently ordered sides and no relationship field.
Answer submission accepts exactly one option, typed-answer, or complete
matching-bijection form. Only transaction-specific post-commit or
ownership-scoped reconciliation feedback contains that submitted question's
narrow correct-answer form.

The answer body has an explicit 8192-byte transport limit and documents generic
no-store `413` behavior. The ownership-scoped recorded-answer response supports
lost-response reconciliation. Raw/canonical learner text is absent from attempt,
reconciliation, analytics, and recovery contracts. Authored answer keys are
absent before submission and from analytics/recovery data; only the
transaction-specific post-commit response or reconciliation result may contain
the submitted question's narrowly scoped feedback described above.

The Phase 3 intake contract stops before course creation. It creates a bounded
resumable multipart XLSX upload, accepts an exact versioned object for isolated
S3/SQS/ClamAV processing, exposes owner-scoped no-store preview/report pages,
and appends approval for one provenance-binding digest. It accepts no client
owner, object key/version, scanner verdict, validation result, workflow state,
course ID, or publication claim. There is deliberately no import `commit`
endpoint until the immutable content schema and production Type-D allocation
semantics can represent the workbook without loss.

Generate clients with the pinned OpenAPI Generator container:

```powershell
./scripts/generate-clients.ps1
```

Without Docker, set `OPENAPI_GENERATOR_JAR` to an official 7.14.0 CLI JAR and
put Java 21 on `PATH`; the same script verifies the pinned artifact checksum
before executing the local generator.
Both modes also require Dart 3.12 from Flutter 3.44 to produce and format the
checked-in JSON serializers and client sources. The script cleans only the two
fixed generated-output paths before rebuilding them, and CI rejects modified,
deleted, or untracked drift.

When a generated-client `pubspec.lock` already exists, generation preserves it
and uses Dart's enforced-lockfile mode. A dependency change must therefore be a
deliberate lockfile update instead of a registry-timing side effect.

Generated output is deterministic and must be reviewed with the contract change.
`pnpm test` validates representative response data against the JSON Schema
components and proves that required, closed-object, and canonical-language
constraints fail when deliberately violated.

Sensitive import models also carry an explicit
`x-kelimio-redacted-field-names` list. This duplicates the per-property
sensitivity marker intentionally: OpenAPI Generator does not preserve sibling
vendor extensions consistently for referenced and composed properties, while
the checked-in Dart model template must redact every listed value from
`toString()` diagnostics.
