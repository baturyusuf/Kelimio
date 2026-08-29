# ADR-023: Owner-Scoped Teacher Course Analytics

- Status: Accepted
- Date: 2026-08-29
- Decision owners: Product owner and architecture
- Extends: ADR-002, ADR-003, ADR-013, and ADR-022

## Context

Teachers can create, edit, preview, invite learners to, and publish their own
courses, but they cannot yet see whether learners are using those courses or
how the course is performing. The existing learner-course progress projection
is owned by the progress module and is release-aware and rebuildable from
append-only learning facts. Reading that table from the course-editor module
would violate module ownership. Returning learner rows, identities, answer
text, selected options, matching relationships, or small-cohort performance
would also create unnecessary privacy and answer-disclosure risk.

Publication can temporarily leave progress projections on different releases.
An aggregate computed while learning deliveries or release reprojection are
unresolved could mix incomplete current-release data with stale rows and look
authoritative even though it is not.

## Decision

### Authority and module boundary

- The versioned API exposes one read-only endpoint for analytics of one course.
- The authenticated user must have current teacher authorization and be the
  immutable owner of the requested course. A course that is absent or owned by
  someone else returns not found so ownership cannot be enumerated.
- The course-editor application service verifies teacher access and ownership,
  then calls a narrow application query owned and implemented by the progress
  module. The course-editor module never reads progress, attempt, score, outbox,
  or projection tables.
- PostgreSQL learning facts remain authoritative. The analytics response is a
  disposable projection view and creates no new score, entitlement, learning,
  audit, or commerce fact.

### Freshness and release consistency

- Analytics is bound to the course's current active immutable release.
- The progress module reports `updating=true` and omits the complete metrics
  object while any learning projection delivery for the course is absent,
  pending, processing, failed, or dead, or while the latest reprojection job for
  the active release is not completed. Dead work is never presented as fresh.
- Once stable, aggregation includes only progress rows representing the active
  release. Rows for retired releases are excluded rather than mixed into a
  current aggregate.
- A stable course with no recorded activity returns an explicit zero-valued
  metrics object. The latest projection timestamp is nullable when no activity
  exists.

### Privacy-preserving metrics

- The stable metrics object exposes only the number of learners with recorded
  activity for the active release.
- Answer and completion performance is returned only when at least three
  learners have recorded activity. Below that threshold, the performance object
  is null. The threshold is server-authoritative and is not controlled by the
  client.
- Available performance contains aggregate answered-question, correct-answer,
  completed-attempt, and passed-attempt counts. Ratios are presentation-only
  derivations from those aggregates.
- Responses never contain learner identifiers, names, email addresses,
  invitation tokens, raw or canonical typed answers, option identifiers,
  correct answers, submitted or authored matching relationships, per-learner
  rows, or score events.
- Mobile displays updating and small-cohort states explicitly with retry actions
  and never substitutes fake or client-computed success data.

## Data and migration impact

No schema migration is required. The progress module aggregates the existing
release-aware `learner_course_progress_projection` only after its delivery and
reprojection freshness checks pass. The view remains rebuildable from
PostgreSQL facts. The API contract, generated clients, backend integration
tests, mobile domain mapping, localization, RTL/text-scale coverage, and status
documentation move together.

## Consequences

- Teachers gain useful course-level adoption and performance visibility without
  exposing individual learning history or answer material.
- Small internal tests with fewer than three active learners show activity but
  intentionally suppress performance counts.
- Operationally unresolved projections remain visible as updating instead of
  silently presenting partial data.
- Individual learner drill-down, cohort segmentation, exports, and warehouse
  analytics require a later ADR with consent, retention, access, and disclosure
  rules.
