# ADR-011: Idempotent Import Commit and Initial Content Draft

- Status: Accepted
- Date: 2026-08-02
- Decision owners: Architecture and product implementation
- Extends: ADR-003 and ADR-010

## Context

ADR-010 deliberately stops an imported workbook at an immutable approval fact.
The governing master requirement nevertheless requires a separate idempotent
`commit` command that creates a new course exactly once. The existing learning
slice has flat tests and runtime question revisions, but does not yet preserve
the workbook's complete `Level > Unit > Topic > Test > Question` hierarchy,
all support-language translations, allocation metadata, source coordinates, or
course import settings. Reusing that flat runtime projection as the import
source of truth would lose approved content.

The existing schema also requires every course to point at an `ACTIVE` release,
even while the course is `DRAFT`. That was sufficient for the local starter
fixture but conflicts with real authoring: an unpublished course must be able to
own an immutable draft release without making it active or learner-visible.

Production Type-D workbook composition, author eligibility and consent,
retention controls, and the stored minimum-client capability gate remain open.
The reviewed workbook contains matching-group provenance on word rows, but the
approved rules do not yet authorize converting those rows into Type-D
questions. A commit must preserve those values without guessing or publishing
them.

## Decision

### Command boundary

- `POST /v1/courses/imports/{importId}/commit` is exposed only while the real
  import subsystem is enabled in `local` or `test`; the existing startup guard
  continues to reject import enablement in staging or production.
- The command requires a completed profile, object ownership, an idempotency
  key, `APPROVED` state, and the exact approval-binding digest. It consumes only
  the immutable PostgreSQL preview and approval facts; the API never reopens or
  reparses workbook bytes.
- One database transaction creates the course draft, immutable content graph,
  initial committed change set, draft release manifest, import-commit fact,
  state event, and transactional outbox event. No S3, scanner, queue, or other
  provider call occurs inside the commit transaction.
- A lost response or identical retry returns the original identifiers. A
  changed digest, changed idempotency command, second conflicting commit, stale
  state, incomplete preview, or legacy preview without a commit schema fails
  closed and creates no second course.

### Initial content graph

- Commit creates one `DRAFT` course with no active release and one immutable
  `DRAFT` course release. The release is a complete candidate manifest, not a
  publication or entitlement boundary.
- Stable UUID identities are created for levels, units, topics, tests, and
  questions. Immutable revision rows retain display values separately from
  stable identity, and release-specific manifest relations retain explicit,
  contiguous positions for the entire hierarchy.
- Existing `test_revision` and `question_revision` rows remain the learning
  runtime revision identities. Import-owned authoring metadata stores resolved
  test mode, allocation kind/reason, source coordinates, record type, target
  text, translations, authored distractors, matching-group provenance, hidden
  state, and notes without flattening or truncating the approved preview.
- A committed `ContentChangeSet` has no base release because this is initial
  course creation. It records `EXCEL_IMPORT` origin and immutable create/commit
  events. Later edits must create new mobile-authoring change sets and new
  revisions; the original import graph is never rewritten.
- The imported settings snapshot preserves target-language display name,
  ordered support languages, default mode, allocation limits, completion
  threshold, pricing source, typed-answer alternative limit, and offline mode.
  The course table holds only the current catalog-level subset.

### Publication separation and compatibility

- `course.active_release_id` is nullable only while the course is `DRAFT`.
  `PUBLISHED`, `HIDDEN`, and `REMOVED` courses must continue to point to exactly
  one `ACTIVE` release. A draft course may not point at an active release.
- Import commit never activates question revisions, test revisions, or the
  draft release; never changes course publication status; and never creates an
  enrollment, entitlement, invitation, offline package, projection job, or
  public catalog result.
- Raw matching-group values are preserved as authoring provenance. They are not
  converted into Type-D questions. Publication remains blocked until a later
  accepted ADR fixes group allocation/conversion and a stored client-capability
  gate enforces compatible clients.
- The outbox event is `course.draft-created-from-import.v1` and contains opaque
  identifiers and counts only. It is not `ContentReleasePublished` and cannot be
  consumed as evidence of publication.

### Preview compatibility

- New valid previews persist a versioned, normalized settings payload marked
  `import-content-v1`. Approval continues to bind the existing canonical
  preview digest, which already covers those settings and the allocation digest.
- V9 previews created before this migration retain their approval-only evidence
  but have no reconstructed settings payload. They are intentionally not
  commit-eligible; the migration never guesses settings or reparses an archived
  workbook.

## Data and migration effect

- Flyway V10 makes `course.active_release_id` nullable under a stricter
  lifecycle trigger, adds the versioned preview settings payload, expands the
  import state machine with terminal `COMMITTED`, and adds immutable import
  commit provenance.
- V10 adds content change sets/events, stable level/unit/topic identities and
  revisions, release hierarchy manifests, import settings, test/question
  authoring metadata, translations, and authored distractors. Database
  constraints and deferred commit validation cross-check ownership, provenance,
  counts, draft states, and the outbox tuple.
- Existing active courses, releases, attempts, score/energy facts, outbox facts,
  projections, and V9 approval records are preserved. No existing preview is
  upgraded to commit-ready without authoritative settings evidence.

## Consequences

- A real approved workbook can become one durable, editable course draft
  without becoming learner-visible or weakening unresolved production gates.
- Every approved row and hierarchy position has a stable identity and immutable
  revision boundary suitable for later mobile authoring and publication work.
- Approval, commit, and publication remain three distinct facts. Tests must
  prove that commit is exactly-once, owner-scoped, digest-bound, fully atomic,
  and produces zero active/public/entitlement side effects.
- The next content milestone remains production Type-D composition plus the
  stored minimum-client capability gate, followed by publication and
  reprojection.
