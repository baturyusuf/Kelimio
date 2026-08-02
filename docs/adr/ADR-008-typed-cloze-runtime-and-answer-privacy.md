# ADR-008: Typed-Cloze Runtime and Answer Privacy

- Status: Accepted
- Date: 2026-08-02

## Context

The governing master requirement and reviewed workbook define Type C as a
target-language sentence with one `---` blank, one primary correct answer, and
at most one alternative correct answer. Correctness, case handling, Unicode
normalization, and whitespace handling belong to the backend. A learner's raw
typed answer must not enter logs or analytics.

The existing online transaction supports only option IDs. Its immutable answer
fact requires `selected_option_id`, its post-commit response always requires
`correctOptionId`, and its idempotency fingerprint binds the selected option.
Extending those fields with raw text would create unnecessary retention and
could leak a sensitive free-form value through logs, events, or replay storage.

ADR-000 says `correctOptionId` remains required because only option questions
existed when that conflict was normalized. Type C requires the same narrowly
post-commit feedback without inventing an option identity.

## Decision

### Canonical mapping and payload

| Boundary | Value |
| --- | --- |
| Workbook record | `Cümle Yazmalı` |
| PostgreSQL question revision | `question_type = 'C'` |
| API and mobile domain | `TYPED_CLOZE` |
| Prompt | Exactly one literal ASCII `---`, counting overlaps |
| Answers | One primary and zero or one alternative |

Attempt questions keep a required `options` array. Types A and B contain
exactly four options; Type C contains exactly zero. No authored answer,
alternative, comparison key, or normalization policy appears before submission.

`SubmitAnswerRequest` contains exactly one of `selectedOptionId` and
`typedAnswer`. The server derives question type, target language, and evaluation
policy from the attempt's pinned immutable revision. The client cannot assert
those values, correctness, score, energy, or match result.

The complete answer-submission body has an 8192-byte transport cap. Declared
oversize and chunked bodies are rejected before JSON allocation, authentication,
or transactional/idempotency work with a generic `413` Problem response,
correlation identifier, and `Cache-Control: no-store`. Locale-independent raw
answer envelope checks also run before the transactional service; authoritative
locale-pinned canonicalization and grading remain inside the service.
The pre-Jackson filter matches with Spring MVC `PathPattern` semantics rather
than a raw-path regular expression, so matrix parameters and percent-encoded
path literals cannot route to the controller while bypassing the cap.

After the answer transaction commits, A/B responses contain only
`correctOptionId`; C responses contain only the primary authored
`correctAnswerText`. This narrows ADR-000's earlier globally required
`correctOptionId` statement while preserving its security rule: correct
feedback is transaction-specific and never appears in attempt-start,
durable/mobile recovery state, cache, analytics, or outbox data. The
ownership-scoped post-commit reconciliation response is the sole recovery
exception and returns only the same transaction-specific feedback.

POST answer responses and the ownership-scoped reconciliation response use
`Cache-Control: no-store`. A new
`GET /v1/attempts/{attemptId}/answers/{submissionId}` returns a committed result
only when both records belong to the authenticated user. Absence and ownership
mismatch both return not found.

### `typed-answer-v1` comparison

The comparison policy is immutable revision data and applies identically to
authored primary/alternative answers and learner input:

1. accept 1 through 500 Unicode code points within the bounded UTF-8 limit;
2. reject malformed surrogate data, private-use/unassigned characters,
   controls, line/paragraph separators, and bidi-spoofing format characters;
   allow only ZWNJ and ZWJ among format characters;
3. normalize to Unicode NFC;
4. trim Unicode whitespace at both ends and collapse internal Unicode
   whitespace runs to one ASCII space;
5. uppercase and then lowercase with the pinned canonical target-language
   locale, never the app/user/device locale;
6. normalize to NFC again.

Accent, punctuation, apostrophe, hyphen, and transliteration differences remain
meaningful. There is no fuzzy matching or dynamically inferred synonym. An
alternative whose comparison key equals the primary key is invalid. Unknown
policy versions fail closed. A behavior change requires a new policy version
and new question revision rather than reinterpretation of existing history.

### Durable fact and replay privacy

Question revisions store the optional alternative display text, policy version,
pinned answer language, and server-only authored comparison keys. These fields
are immutable and Type C has no option rows.

The answer fact records either `OPTION` or `TYPED_TEXT`. A typed fact stores no
raw or canonical learner text. It stores a random 16-byte salt, a 32-byte
SHA-256 digest over length-prefixed policy/identity/canonical-answer data, and a
match ordinal (`0` none, `1` primary, `2` alternative). The digest is a
database-confined equality token, not anonymous data.

Command idempotency fingerprints exclude typed text. Replay canonicalizes the
new request under the pinned policy, recomputes the digest with the stored salt,
and compares in constant time. Canonically equivalent spelling/case/whitespace
replays the committed response. A different canonical answer under the same
submission or idempotency identity returns conflict and creates no additional
answer, score, energy, attempt, or outbox fact.

Raw/canonical typed text, digest/salt, authored answer keys, and post-commit
correct-answer feedback are forbidden from attempt events, outbox payloads,
analytics, metrics, problem details, and logs. Request objects redact their
string representation, and response/domain feedback objects redact answer-key
fields from diagnostic strings. The normal learning event retains only stable
IDs, correctness, score deltas, energy, and attempt state.

Mobile recovery stores only the answer kind and submission identity for Type C;
it never stores learner text. HTTP `413` and `422` are typed validation failures:
the app clears the input, returns to Type-C presentation, and reuses the same
reserved submission ID for a corrected value. This preserves idempotency and
keeps the rejected value out of recovery. Option-answer validation retains its
existing fail-closed behavior.

## Data and compatibility impact

- A forward-only V6 migration expands question revisions to A/B/C, applies the
  exact-one marker to B/C, adds immutable typed-answer metadata, and makes
  option rows conditional on question type.
- Existing A/B revisions and answer facts are preserved. Existing answer rows
  are classified as `OPTION`; the nullable option FK remains mandatory for that
  answer kind.
- Type-C answer facts add conditional typed evidence and database checks tying
  match ordinal to correctness and alternative availability.
- OpenAPI, backend, generated clients, and mobile support ship together. Older
  clients fail closed on `TYPED_CLOZE`; a production release containing C must
  not activate until the supported-client gate is met.
- The local starter course receives a new immutable origin key and adds the
  exact reviewed `Giriş` Type-C row. Prior local starter releases are not
  mutated.

## Consequences

- Type C reuses ADR-002's authoritative score/energy/idempotency/outbox
  transaction without allowing client-owned correctness.
- Primary and alternative authored answers remain in immutable revisions for
  authoritative grading; only the primary is returned as post-commit feedback,
  while learner free-form text is not retained.
- Reconciliation can recover a committed response after a lost HTTP response
  without broadening ownership visibility or permitting a resubmission.
- Type D, production workbook commit, fuzzy grading, and client-side online
  answer evaluation remain unsupported.
