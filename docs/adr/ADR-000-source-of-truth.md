# ADR-000: Source of Truth and Conflict Normalization

- Status: Accepted
- Date: 2026-07-21
- Decision owners: Product owner and architecture

## Context

Kelimio starts from five supplied requirement artifacts that differ in authority and sometimes in representation:

1. the production master prompt;
2. the latest course workbook `kurs_excel_plani_v3_test_numarali.xlsx`;
3. the backend architecture PDF;
4. the frontend/mobile architecture PDF;
5. the architecture comparison/recommendation PDF.

The workbook is executable product input, while the PDFs contain architecture scenarios and recommendations. Silent conflict resolution would make import results, data contracts, and release behavior depend on whichever document an implementer happened to read.

## Decision

### Authority order

In the absence of a newer explicit owner amendment, conflicts are resolved in this order:

1. explicit and current provisions in the production master prompt;
2. the latest supplied Excel workbook;
3. the backend architecture PDF;
4. the frontend/mobile architecture PDF;
5. the architecture comparison PDF.

A newer explicit owner instruction is an amendment to this list, not a reason to rewrite history. It must be recorded in a new or superseding ADR. Repository documentation, tests, schemas, and code are evidence of implemented decisions; they may not silently override the governing artifacts.

Every newly discovered conflict records the sources, selected interpretation, rationale, and data/migration impact in an ADR before implementation.

### BCP 47 versus workbook casing

Conflict:

- the master contract requires BCP 47 language tags and separates language from country;
- the workbook uses uppercase ISO-like values and dynamic headers such as `TR`, `EN`, `AR`, and `FR`.

Resolution:

- workbook values and dynamic language headers are accepted case-insensitively at the import boundary;
- they are parsed as language tags, validated, and converted to canonical BCP 47 form before entering domain/API data;
- primary language subtags are lowercase (`TR` becomes `tr`, `EN` becomes `en`); script subtags use title case and region subtags use uppercase when present;
- equality and uniqueness use a case-insensitive normalized key so variants cannot create duplicate languages;
- the target language cannot also appear as a support language, and duplicate support headers after normalization are a critical import error;
- the original workbook spelling is retained only in import audit/error context, not as the domain key.

Data/migration effect: initial schema and contracts store the canonical tag plus a normalized uniqueness key. No production migration exists yet. Future imports require regression fixtures for uppercase workbook values and compound BCP 47 tags.

### Blank test-mode inheritance

Conflict/ambiguity:

- the workbook defines `Test Modu (Opsiyonel)` and a course default; example explicit tests set a mode only on the first row and leave the other rows in the same test blank;
- treating every blank row immediately as the course default would unintentionally produce conflicting modes inside one test.

Resolution:

1. Run deterministic test allocation to obtain the resolved test number within each `Level(sheet) + Unit + Topic` group.
2. Resolve mode for each resulting test as a whole.
3. Ignore blank cells while collecting explicit values. `Varsayılan` means “use the course default,” not a separate runtime test mode.
4. If exactly one distinct nonblank explicit mode exists, all blank rows in that test inherit it.
5. If no explicit mode exists, the entire test inherits the course default (`Karışık` in the supplied workbook unless owner data changes it).
6. More than one distinct effective explicit mode in the same test is a critical import error; do not guess or split the test.

Allowed workbook values are `Varsayılan`, `Karışık`, `Kelime`, `Eşleştirme`, `Seçenekli boşluk`, and `Yazmalı boşluk`. The backend import domain service owns this algorithm; Flutter displays the server preview and does not reimplement it.

Data/migration effect: store one resolved mode on `TestRevision`, preserve row-level raw values in the import report/audit, and add deterministic fixtures for explicit-first-row, all-blank, `Varsayılan`, conflicting, fixed-test, and automatic-test cases.

### Post-submission feedback versus an online answer key

Conflict inside the master prompt:

- the attempt-start rule says the online DTO has no correct-answer key, and the mobile rule says no online answer-key model exists on the client;
- the more specific answer-transaction rule requires the response to contain correct/incorrect status and the correct answer to display after submission.

Resolution:

- catalog, test-start, question, recovery, and offline-package payloads never contain correct answers or a future/full-test answer key;
- only after the server atomically commits a submitted answer may that answer's response reveal `correctOptionId` for immediate feedback;
- the mobile client may hold that single feedback value in transient attempt state, but it may not persist or prefetch a reusable answer-key model;
- logs, analytics, caches, and recovery snapshots must redact or omit `correctOptionId`.

This selects the transaction-specific feedback requirement over a literal reading that would make the required correct-answer feedback impossible, while preserving the security intent of preventing pre-answer extraction. Data/API effect: `AnswerRecordedResponse.correctOptionId` remains required; `AttemptResponse` and persistent mobile recovery models remain answer-key-free. Contract and UI tests must prove both halves.

### Other registered conflicts

| Conflict | Resolution | Detailed record |
| --- | --- | --- |
| PDFs make Flutter conditional; master requires Flutter production mobile. | Flutter is the default Android/iOS implementation. | ADR-001 |
| PDFs treat AWS as one equivalent; master sets AWS as default. | AWS is the production default until an owner-approved superseding ADR. | ADR-001 |
| Master requires Spring Boot stable 3.x/Java 21 while Boot 4 exists upstream. | Pin Spring Boot 3.5.16 and Java 21. | ADR-001 and `docs/VERSIONS.md` |
| Answer flow writes score in the request transaction, while an event table implies an asynchronous Scoring consumer. | Durable score/energy facts are synchronous; projections and downstream effects are asynchronous. | ADR-002 |
| `ContentChanged`, revisions, change sets, and course releases are not fully unified in the PDFs. | Publish an immutable course release from a validated change set and activate it atomically. | ADR-003 |
| The master permits safe cached formula values or rejection, while cached values cannot prove calculation freshness. | Reject every formula cell and parse only inert workbook values inside the isolated import boundary. | ADR-006 |
| Payment diagrams suggest permanent entitlement, but refund/void/chargeback must revoke access. | Entitlement is a revocable state projection derived from immutable store events. | ADR-004 |
| Matching email addresses suggest one person, but email text alone cannot safely authorize an account merge. | The managed OIDC broker links identities only after verified ownership; the backend keys users by stable subject and never auto-links by email. | ADR-005 |
| The workbook represents matching through grouped word rows, while the runtime and scoring model require one question revision and the sources do not define pair-by-pair commands, mixed-mode conversion, or cross-test groups. | Type D is one bounded complete-bijection question under `matching-v1`; `xlsx-v2` performs allocation first and composes only complete in-test groups under immutable source lineage and a stored release-capability gate. | ADR-009 and ADR-012 |

## Consequences

- Import accepts the supplied workbook without leaking its display conventions into API/storage contracts.
- Test behavior is deterministic and explainable in previews and error reports.
- Owner changes remain possible, but they create visible decisions and migration work rather than silent implementation drift.
- New contributors must read this ADR before treating any artifact, schema, or existing code as authoritative.
