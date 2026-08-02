# ADR-017: Local Course Editor Conflict and Recovery

- Status: Accepted
- Date: 2026-08-02
- Decision owners: Architecture and product implementation
- Extends: ADR-003, ADR-013, ADR-014, ADR-015, and ADR-016

## Context

ADR-016 proved a real subsequent immutable release, but its automatic prompt
change did not prove a user-facing edit, optimistic concurrency, process-loss
recovery, or conflict resolution. The proof must not expose an answer key,
silently overwrite another revision, or imply that a complete production
authoring product now exists.

## Decision

- Local/test exposes the first deterministically eligible Type-C question in an
  owned active release. The snapshot includes its hierarchy and prompt, but no
  correct answer, translation, option, distractor, or learner data.
- The server emits a strong ETag derived from the course, active release, and
  question revision. Draft creation requires the exact `If-Match` value, exact
  base release and question revision, plus an idempotency key. A stale value is
  a conflict; no last-write-wins fallback exists.
- The edited prompt is validated server-side as changed, nonblank, at most
  1,000 characters, and containing exactly one literal `---`. A successful
  command writes the real V13 immutable revision/change-set/release facts and
  an identifiers-only outbox event.
- The Flutter operator stores at most one unsaved prompt in operating-system
  secure storage. The bounded record is versioned by stable identifiers and
  ETag, is cleared after successful draft creation, explicit discard, or
  sign-out, and fails closed when malformed. Workbook bytes, answer keys,
  approval bindings, and authoring commands are not stored with it.
- A matching recovery record is restored after process loss. A stale record or
  server conflict shows the starting, personal, and latest published prompts.
  The owner must explicitly use the latest version or reapply the personal
  prompt against the latest ETag before retrying.
- Draft creation and publication remain separate. The mobile operator fetches
  the server-calculated impact and requires a new acknowledgement before
  activating the immutable release.

## Scope and release impact

This is a local/test vertical slice for one Type-C prompt. It does not provide
a complete course-tree editor, multi-question changes, answer editing, author
eligibility, UGC/legal consent, moderation, production IAM, staging evidence,
or production enablement. The existing production launch blocker remains open.

## Consequences

- Local acceptance can exercise a human-authored subsequent release without
  sending answer material to the device or permitting a silent overwrite.
- Process loss preserves bounded unsaved work, while session changes purge it
  with other user-scoped private state.
- Expanding beyond the single eligible prompt requires a later contract and
  ADR covering tree selection, multi-entity impact, validation, and recovery.
