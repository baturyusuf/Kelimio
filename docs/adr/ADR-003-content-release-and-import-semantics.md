# ADR-003: Content Releases, Import Semantics, and Reprojection

- Status: Accepted
- Date: 2026-07-21

## Context

The sources require immutable question/test history, mobile teacher drafts, impact analysis, version conflict handling, offline packages, and reprojected learner progress. They use `ContentChanged`, `ContentChangeSet`, `ContentReleasePublished`, question/test revisions, and course release IDs without fully specifying one publication boundary. Without that boundary, clients could mix revisions, attempts could change beneath users, packages could mismatch online content, and partial publication could corrupt progress.

The workbook also relies on the import normalization and blank test-mode behavior decided in ADR-000.

## Decision

### Draft and revision model

- `Question` and other authored nodes have stable identities.
- Text, answer, option, translation, visibility, placement, or mode changes create immutable revision records; old revisions are never overwritten or deleted by normal authoring.
- Teacher edits accumulate in a `ContentChangeSet` draft with an owner, base release, operation IDs, and expected ETags/revisions.
- The backend validates authorization, field rules, translation completeness policy, hierarchy, test-mode consistency, and optimistic concurrency before accepting a draft change.
- The teacher receives impact analysis before publication.

### Release model

- A `CourseRelease` is an immutable manifest of the exact hierarchy, test revisions, question revisions, translations, visibility, and package-relevant metadata for one course.
- A publish command validates and assembles the complete candidate. In one transaction it persists the immutable release, moves the course's active-release pointer, records the publication audit, and writes `ContentReleasePublished` to the outbox.
- If assembly/validation/transaction fails, the previous release remains active and the change set can be corrected or retried.
- Publication never mutates a prior release. Rollback creates an audited activation of a known-good prior release (and an event), not deletion or in-place reversal.
- A test attempt pins its `courseReleaseId` and `testRevisionId` at start. It never changes revision mid-attempt.
- Offline packages are keyed by `courseReleaseId + supportLanguage + platformFormatVersion`; a new release creates a new package identity.

### Projection behavior

- Publication schedules paged idempotent jobs for affected enrollments with a `contentChangeSetId`/release version.
- Unchanged question revisions preserve mastery; changed revisions start active mastery at zero; lifetime score facts are untouched.
- Old progress projections may be served while a new release projection is building, but responses include their release/version and an updating state. Mixed-version aggregates are not presented as current.
- Failures retry, checkpoint, enter DLQ after policy limits, and expose reconciliation/admin controls. Completion triggers cache/search/package invalidation or refresh events.

### Initial Excel import

- Excel may create a course exactly once. The import commit produces stable IDs, initial immutable revisions, the first course release, and an outbox event idempotently.
- Workbook language casing and test-mode inheritance follow ADR-000.
- Test allocation follows workbook row order, fixed test numbers, optional fill-to-default, automatic groups, and final-small-group rules. The backend owns the algorithm.
- The original workbook and validation report remain immutable audit/support artifacts. A later workbook cannot update the same course.

## Consequences

- Every online attempt, projection, offline package, and support investigation can name the content it used.
- Publication is atomic even though potentially large learner reprojection is asynchronous.
- Mobile must show conflict, publication, and “updating” states rather than claiming immediate global recomputation.
- Initial schema needs course release manifests, active release pointer, change sets, revision tables, ETags/version numbers, release-aware projections, idempotent job checkpoints, and audit/outbox links.
- The initial Excel import requires a nonblank translation for every declared
  support language on each translatable word record and performs no
  cross-language fallback, as recorded in ADR-006. Any future relaxation or
  fallback policy requires a superseding ADR; publication must never silently
  substitute an unrelated language.
