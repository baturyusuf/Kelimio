# API contracts

`openapi/kelimio-api.yaml` is the versioned source of truth for external REST
clients. Backend controller changes and generated clients must pass a contract
drift check in CI.

The first contract intentionally covers the production vertical slice only. It
contains no answer keys in attempt payloads and no client-supplied user, score,
energy, or entitlement claims.

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
