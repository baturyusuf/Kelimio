# ADR-012: Workbook Matching Composition and Release Capabilities

- Status: Accepted
- Date: 2026-08-02
- Decision owners: Architecture and product implementation
- Extends: ADR-003, ADR-006, ADR-009, and ADR-011

## Context

The workbook represents Type-D source material as `Kelime` rows with an
optional `Eşleştirme Grubu`; it has no separate Type-D record type. ADR-009
fixed the runtime as one complete two-to-six-pair question but intentionally
left workbook composition unresolved. The reviewed workbook shows why a
conversion cannot simply group every repeated label: `SELAM` and `TEMEL` cross
explicit WORD-test boundaries, while `EV`, `MARKET`, and `RESTORAN` remain
inside MIXED tests after the governing row-based allocation algorithm.

The runtime already understands `MATCHING`, but a release has no durable
manifest of the client features required to consume it. Relying on release
notes or an app version remembered by an operator would allow an older client
to discover or start content it cannot decode. A numeric app version alone is
also insufficient because Android and iOS build numbers are independent and a
future client can support a feature through different release lines.

## Decision

### Versioned workbook semantics

- `xlsx-v1` retains its existing behavior byte-for-byte: matching test mode is
  rejected and matching-group values are provenance only. Existing previews
  and committed drafts are not reinterpreted.
- `xlsx-v2` uses the same or tighter package/parser security ceilings and the
  same row-based fixed/automatic test allocation. It adds the composition rules
  below. A valid `xlsx-v2` preview is stored as `import-content-v2`.
- The rules version remains in the normalized settings and approval digest.
  Changing composition requires another rules/content-schema version rather
  than changing the meaning of an approved preview.

### Group identity and allocation order

- Test allocation and whole-test mode resolution run first, exactly as required
  by ADR-000 and the production master prompt. Matching composition never moves
  a row, changes a fixed test number, fills a different test, or changes the
  allocation digest.
- A matching label is Unicode-NFC structural text. Identity uses the existing
  locale-independent uppercase-then-lowercase collision key and is scoped to
  `Level + Unit + Topic`. Display/provenance retains the normalized authored
  spelling. The label is neither a global domain identity nor a public answer
  key.
- A group selected for composition must be wholly contained in one resolved
  test. A selected group split across tests is a critical error; the importer
  never silently splits or relocates it.

### Mode-specific conversion

- In a `WORD` test, every word row creates one Type-A question. A matching label
  remains provenance and may cross tests without affecting content.
- In a `MIXED` test, an ungrouped word row creates one Type-A question; all word
  rows sharing one in-scope group create exactly one Type-D question. Cloze
  rows retain Type B or C.
- In a `MATCHING` test, every row must be a word row with a nonblank matching
  group, and every group creates exactly one Type-D question. Other record types
  or ungrouped word rows are critical errors.
- Existing homogeneous B/C test rules remain unchanged. A matching label on a
  non-word row is invalid rather than ignored.

Each selected group must contain two through six rows. Within the group, target
labels and every support-language label must be unique under
`matching-label-v1`, and every row must have all declared translations. Group
pair order is source-row order. The single Type-D question occupies the first
member's position; later group members create no duplicate question. Thus each
source row is consumed exactly once, although the runtime question count can be
lower than the source-row count. Preview, commit facts, and authoring impact
must report both counts.

### Immutable provenance and runtime materialization

- An `import-content-v2` preview records, for every source row, its projected
  question ordinal/type, composition kind, and group position. Approval binds
  the rules version, allocation, normalized content, and settings from which
  those deterministic values are derived.
- Import commit creates one DRAFT Type-D revision per selected group using the
  existing `matching-v1`, `matching-label-v1`, and `matching-order-v1`
  policies. Target/support item IDs are unrelated random UUIDv4 values.
- Every imported question revision has immutable links to all source preview
  rows it consumed. A grouped question links every member in source order, so
  collapsing rows never loses source coordinates, translations, distractors,
  notes, or group provenance. Those source fields remain authoring evidence;
  Type-D runtime options/distractors are not invented from them.

### Stored release capabilities

- Every course release has an immutable, derived set of required capability
  tokens. The initial token is `question.matching.v1`; it is required exactly
  when the release manifest contains a Type-D question revision.
- A database constraint validates the exact derived set before a release may
  become ACTIVE or a course may point at it. An author, client, or controller
  cannot omit a required token to bypass compatibility.
- Student clients advertise a bounded set through the optional
  `X-Kelimio-Client-Capabilities` request header. Missing means the empty set,
  preserving access to releases with no requirements. Tokens use lowercase
  ASCII dot-separated identifiers, are deduplicated, and have strict count and
  length limits.
- Catalog discovery excludes incompatible releases. Direct enrollment,
  attempt, answer/reconciliation, and release-pinned learning access fail with
  a stable `client-upgrade-required` problem when the release requirements are
  not a subset of the advertised set. Existing entitlement is not revoked.
- The current Flutter client advertises its compile-time capability set; it
  never infers capabilities from server content. Capability claims are a
  compatibility signal, not authorization, integrity, entitlement, or an
  anti-tamper control.

Publication, rollback, and a store-operated minimum-version policy remain
separate Phase-3 work. This ADR supplies the durable manifest and request-time
gate they must use; it does not activate or publish an imported draft.

## Data and compatibility impact

- Flyway V11 adds immutable question-to-import-source links, import composition
  facts/counts, release capability manifests, and deferred cross-checks. It
  backfills one source link and `ROW` composition for existing V10 imported
  A/B/C revisions without changing their meaning.
- `course_import_commit.row_count` remains the approved source-row count;
  `question_count` and `matching_question_count` are added explicitly.
- OpenAPI preview and commit models expose the projected counts/capabilities and
  row composition without exposing matching relationships. Generated clients
  remain the source for transport models.
- Owner-scoped import status exposes the stored rules version as the closed set
  `xlsx-v1 | xlsx-v2`. Retained legacy V9 imports must remain decodable, while
  the current intake emits `xlsx-v2`; unknown future versions fail closed until
  the contract and clients deliberately add them.
- Older clients that send no capability header continue to use releases whose
  required set is empty and cannot discover or enter Type-D releases. Current
  clients send `question.matching.v1` on the affected calls.

## Consequences

- The supplied workbook has an explainable result: cross-test labels in WORD
  tests remain Type-A provenance, while the in-test MIXED groups become Type-D.
- Row allocation stays faithful to the governing algorithm, and invalid future
  workbooks fail with actionable preview errors rather than silently changing
  tests or duplicating learning content.
- Compatibility is enforced from immutable release content at the database and
  request boundaries. Documentation or operator memory is no longer the gate.
- Production import and publication remain blocked on author eligibility,
  consent, provider/IAM/retention controls, authoring/conflict UI, immutable
  publication/rollback, and staging evidence.
