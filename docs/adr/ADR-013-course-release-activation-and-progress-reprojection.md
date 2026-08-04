# ADR-013: Course Release Activation and Progress Reprojection

- Status: Accepted
- Date: 2026-08-02
- Decision owners: Architecture and product implementation
- Extends: ADR-002, ADR-003, ADR-011, and ADR-012

## Context

An approved workbook can now create one complete immutable `DRAFT` release,
including Type-D questions, exact source lineage, and its derived client
capability manifest. The draft deliberately remains invisible to learners.
There is no owner-scoped impact preview, atomic activation command, publication
audit fact, rollback operation, or release-aware progress reprojection.

Simply changing `course.publication_status` would be unsafe. A partial failure
could leave draft question revisions underneath an active release, an older
client could enter unsupported content, a retry could publish twice, and
learner active mastery could continue to count superseded revisions. Conversely,
recalculating lifetime score would rewrite append-only learning history.

Production author eligibility, versioned author consent, moderation, AWS
least-privilege roles, retention controls, and staging evidence are unresolved.
The implementation therefore needs a real local/test boundary without creating
a permissive production fallback.

## Decision

### Availability and authority

- Course release activation is enabled only when
  `KELIMIO_COURSE_RELEASE_ENABLED=true` in `local` or `test`. Enabling it in
  staging or production fails application startup until the external author and
  operational gates are implemented.
- The authenticated completed-profile user must be the immutable course owner.
  The capability header is unrelated to author authority.
- Import approval, import commit, impact preview, and activation remain distinct
  operations. Import commit never auto-publishes.

### Impact preview and optimistic binding

- The owner first reads an impact preview for one exact target release. It
  reports the current and target release identities, operation kind, release
  revision, added/changed/unchanged/removed stable questions, affected active
  enrollments, target question count, and required client capabilities.
- A canonical SHA-256 impact binding covers the course, expected current
  release, target release and revision, operation, source change set, sorted
  target/current stable-question-to-revision manifests, and sorted capability
  set. The informational enrollment count is excluded because enrollment may
  legitimately change between preview and activation.
- Activation requires that exact binding plus an explicitly required nullable
  `expectedActiveReleaseId`. A stale pointer, target manifest, source change
  set, or capability set fails with conflict before any state change.

### Atomic activation and rollback

- Initial publication activates a revision-1 `DRAFT` release for a `DRAFT`
  course with no active release. Later publication activates a newer `DRAFT`
  release. Rollback activates a known `RETIRED` release while the course remains
  published or hidden. A removed course cannot be reactivated by this command.
- Before release activation, every target question revision and test revision
  in the manifest is activated in dependency order. Existing active revisions
  are reused; no revision content is rewritten.
- An import commit already materializes exactly four immutable runtime options
  for every Type-A and Type-B revision. Type B uses its reviewed correct answer
  and three reviewed distractors. Type A uses the correct source row plus the
  next three distinct vocabulary rows in cyclic source order; their authored
  translations produce the same stable option identities in every course
  support language. Insufficient distinct translated rows fail closed.
  Activation never invents or repairs content. Type-C and Type-D remain
  optionless; Type-D relationships come only from its authored matching tables.
- In one PostgreSQL transaction the previous active release is retired when
  present, the target becomes active, the course pointer and initial publication
  status change atomically, an append-only activation fact is written, a
  transactional outbox event is appended, and one reprojection root job is
  scheduled. Failure leaves the previous release and course pointer unchanged.
- Publication emits `content.release-published.v1`; rollback emits
  `content.release-rollback-activated.v1`. Payloads contain identifiers,
  revision/count/capability metadata only and no authored text or answer data.
- An idempotency key is bound to the canonical command. A lost-response retry
  returns the original activation. Reusing a key for another command fails.
- A release may be a publication target only once, while a retired known-good
  release may be selected by multiple audited rollback cycles. Rollback never
  deletes or mutates prior activation facts.

### Release provenance and database enforcement

- Every newly assembled release is linked immutably to the committed content
  change set that produced it. Existing imported draft releases are backfilled
  from their import commit; legacy local starter releases remain grandfathered
  but are not valid new publication targets.
- Deferred database checks require an activated release to have a complete,
  contiguous manifest of active test/question revisions, no stable question
  mapped to conflicting revisions, and the exact derived capability set from
  ADR-012.
- The activation fact is deferred-cross-checked against final course/release
  state, its source change set, exact outbox payload, delivery row, and the
  scheduled reprojection job. These guarantees do not depend on controller
  behavior.

### Paged idempotent reprojection

- Each activation creates one root job with an enrollment-time cutoff. A worker
  reads active enrollments in stable `(enrolled_at, enrollment_id)` pages up to
  that cutoff and rebuilds each learner-course projection idempotently. Users
  enrolling after activation already start on the new active release and are
  outside the snapshot.
- Active score is rebuilt only from mastery rows whose exact question revisions
  are present in the course's current active release. Unchanged revisions retain
  mastery; changed or removed revisions contribute zero. Lifetime score remains
  the sum of append-only score facts and is never reduced or rewritten.
- The learner projection stores the release it represents. Progress responses
  expose `courseReleaseId` and `updating`; a stale represented release, a pending
  release job, or pending answer events keeps `updating=true`.
- Jobs checkpoint every page, retry bounded failures, retain a sanitized error
  type, and enter `DEAD` after the configured limit. Publication itself does not
  claim global reprojection completion.

## Data and compatibility impact

- Flyway V12 adds release-to-change-set provenance, append-only activation facts,
  paged reprojection jobs, activation/manifest constraints, and the represented
  release on learner-course projections.
- OpenAPI adds owner-scoped impact and activation operations plus release-aware
  progress fields. Generated clients remain the transport source of truth.
- Existing active starter content and learning facts are preserved. Existing
  progress rows are backfilled to their course's active release where one exists.
- The current import and Android acceptance paths advance to Flyway V12; no
  production deployment, store publication, entitlement, or legal state changes.

## Consequences

- A locally imported draft can cross a real, auditable publication boundary and
  become visible only after explicit impact acknowledgement.
- Rollback changes the active immutable manifest without changing attempt facts,
  answer facts, score facts, or lifetime score.
- Large enrollment sets do not make the publication transaction unbounded, and
  clients can distinguish current progress from a projection still catching up.
- Production release remains blocked until author/legal/IAM/retention/staging
  evidence is complete; the existence of local/test activation is not launch
  evidence.
