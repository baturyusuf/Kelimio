# ADR-007: Multiple-Choice Cloze Runtime Contract

- Status: Accepted
- Date: 2026-08-01

## Context

The governing master prompt and the frontend/mobile architecture both define
Type B as a target-language sentence containing exactly one literal `---`,
with one correct answer and three distractors. The secure workbook preview
already recognizes this record as `MULTIPLE_CHOICE_CLOZE`, but the published
attempt contract, PostgreSQL constraint, backend runtime, local starter course,
and Flutter client currently support only Type A word multiple choice.

Type B has the same learner command shape as Type A: the learner chooses one
server-issued option and submits its opaque ID. Introducing a separate answer
transaction would duplicate scoring, energy, idempotency, and append-only fact
semantics without changing authority.

## Decision

The canonical Type-B mapping is:

| Boundary | Value |
| --- | --- |
| Workbook record | `Cümle Seçenekli` |
| PostgreSQL question revision | `question_type = 'B'` |
| API and mobile domain | `MULTIPLE_CHOICE_CLOZE` |
| Prompt | Raw target-language sentence containing exactly one literal ASCII `---` |
| Options | Exactly four server-issued options, exactly one marked correct |
| Submission | Existing `selectedOptionId` command |

The exact-one rule counts overlapping occurrences. Runs such as `----` or
`------`, a missing marker, and two separated markers are invalid. PostgreSQL
enforces the invariant for stored Type-B revisions; the backend also validates
released content before opening an attempt, and the mobile domain rejects an
invalid payload fail closed.

The backend preserves the raw `---` marker in the answer-key-free attempt
payload. Flutter renders that marker inline as one visual blank while retaining
the sentence as one wrapping, bidirectional paragraph. The accessibility tree
announces a localized word for the blank rather than three punctuation marks.

Type A and Type B share the authoritative transaction from ADR-002. Correctness
is derived from the server-owned option row. Score, energy, attempt facts,
idempotency, post-commit feedback, and outbox behavior are unchanged. No correct
flag or answer key is added to attempt-start or recovery data.

This decision does not enable Type C, Type D, production workbook commit, or
automatic distractor generation. Those remain separate milestones because
they require additional answer privacy, normalization, group-scoring, or import
approval semantics.

## Data and compatibility impact

- A forward-only V5 migration expands the immutable revision type constraint
  from `A` to `A`/`B` and adds the Type-B prompt invariant. Existing Type-A data
  is unchanged.
- The OpenAPI enum gains `MULTIPLE_CHOICE_CLOZE`. Backend, generated clients,
  and Flutter support ship together because older clients fail closed on an
  unknown question type.
- The local-only starter course receives a new origin key and an immutable mixed
  A/B release. Existing local Type-A starter releases are not mutated.

## Consequences

- Type B uses the already-tested server-authoritative answer path and does not
  widen the client-owned command surface.
- Invalid cloze content cannot be published into an attempt by bypassing the
  workbook validator.
- Bidirectional layout and screen-reader behavior become explicit contract and
  widget-test concerns.
- Production remains blocked on the full import/authoring/release workflow and
  the unresolved launch gates; this slice is local engineering evidence only.
