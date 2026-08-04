# ADR-016: Subsequent Authoring Release and Rollback Proof

- Status: Accepted
- Date: 2026-08-02
- Decision owners: Architecture and product implementation
- Extends: ADR-003, ADR-011, ADR-012, ADR-013, and ADR-015

## Context

The reviewed workbook path can create and explicitly publish one immutable
revision-1 course release. ADR-013 also defines later publication and rollback,
but there was no non-Excel producer capable of assembling a second sourced
release. As a result, release transition and progress-reprojection behavior had
only empty initial-publication evidence.

A test-only SQL shortcut would not be sufficient. A later release must have a
real committed change set, exact revision provenance, a complete immutable
manifest, an identifiers-only outbox fact, owner authorization, idempotency,
and the same publication boundary used by every other release. The proof must
also expose lifecycle errors that cannot appear during initial publication.

The production mobile editor, author eligibility, UGC consent, ETag conflict
resolution, moderation, AWS custody, and staging operations remain unresolved.
The producer therefore needs an explicit local/test boundary without becoming
a permissive production authoring fallback.

## Decision

### Local/test availability and owner authority

- `KELIMIO_LOCAL_COURSE_AUTHORING_ENABLED=true` is accepted only in `local` or
  `test`. Enabling it in any other environment fails application startup, and a
  disabled command returns not found.
- The command is available at the explicit development route and requires an
  authenticated completed-profile user who owns the course.
- The request binds one exact active base release and an idempotency key. A
  stale base, an unpublished course, a course owned by someone else, or a second
  unpublished draft from the same base fails closed.
- The proof selects the first eligible Type-C revision in deterministic release
  order and changes only its prompt. It never accepts or returns authored answer
  material. This narrow behavior is evidence for the authoring/release
  machinery, not the production editor contract.

### Real subsequent-release facts

- The producer creates one committed `MOBILE_AUTHORING` content change set with
  immutable `CREATED` and `COMMITTED` events and the current active release as
  its base.
- Flyway V13 adds generic append-only source-change-set links for test and
  question revisions. Existing imported revisions are backfilled from their
  authoring provenance, and all later import commits write the generic links as
  part of their existing transaction.
- One new Type-C question revision and its containing test revision are created
  as `DRAFT`. All unchanged question, test, hierarchy, and capability revisions
  are reused in a complete new `DRAFT` release manifest.
- Revision numbers are the next number after the maximum durable revision for
  that stable course, test, or question identity. Editing a rolled-back release
  therefore creates a new branch revision rather than colliding with or
  overwriting a retired revision.
- `course_authoring_commit` is an append-only root fact. A deferred database
  check verifies ownership, the active base, change-set lifecycle, revision
  provenance, the one-question/one-test manifest substitution, unchanged
  hierarchy and capability manifests, and the exact transactional outbox fact.
- The event `content.release-draft-created.v1` contains identifiers and the
  release revision only. It contains no prompt, translation, answer, distractor,
  or workbook material.

### Correct later publication and rollback ordering

- Initial publication may activate draft revisions directly because no stable
  revision is already active. Later publication and rollback cannot: PostgreSQL
  permits only one active revision for each stable question and test.
- For a later transition, the transaction first retires the current release,
  then retires only test and question revisions that are not reused by the
  target manifest. It activates target question revisions, then target test
  revisions, then the target release, and finally changes the course pointer.
- Unchanged revisions remain active throughout. Any failure rolls the complete
  transaction back, preserving the previous active release and course pointer.
- Rollback uses the same sequence in reverse manifest direction. A retired
  known-good revision can become active again without mutating attempts,
  answers, mastery, score events, or prior activation facts.

### Non-empty progress proof

- Real-PostgreSQL integration creates a learner enrollment and server-scored
  mastery on the revision that will change.
- Publishing the second release reprojects active score to zero for that
  superseded revision while lifetime score remains unchanged.
- Rolling back the first release restores the prior active mastery and again
  leaves lifetime score unchanged.
- Both transitions create distinct activation, outbox, and completed paged
  reprojection facts. A subsequent edit after rollback produces revision 3,
  proving monotonic revision numbering across a branch.

## Data and compatibility impact

- Flyway V13 adds `test_revision_source_change_set`,
  `question_revision_source_change_set`, and `course_authoring_commit` plus
  append-only and deferred integrity enforcement.
- OpenAPI adds the owner-scoped local/test subsequent-revision command and
  identifier-only response. Dart and TypeScript clients are regenerated from
  the contract.
- The existing release activation contract remains compatible. Its internal
  transition sequence now supports changed revisions and rollback as originally
  required by ADR-013.
- Existing learning, score, energy, import, release, and outbox facts are not
  rewritten. Legacy local starter revisions without imported authoring
  provenance remain grandfathered and are not valid inputs to this producer.

## Consequences

- Local/test now has a real non-Excel subsequent-release source and non-empty
  publish/rollback/reprojection evidence without pretending that the production
  editor exists.
- Database enforcement detects incomplete manifests, false provenance,
  authored-content leakage in the event contract, and accidental mutation
  independently of controller behavior.
- Production authoring remains blocked on the full tree/editor contract,
  ETag/If-Match conflict and diff/reapply UX, eligibility/consent/moderation,
  least-privilege deployment, and staging evidence.
