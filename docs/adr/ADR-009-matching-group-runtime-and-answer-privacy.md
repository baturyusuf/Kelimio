# ADR-009: Matching-Group Runtime, Scoring, and Answer-Key Privacy

- Status: Accepted
- Date: 2026-08-02

## Context

The governing master requirement defines Type D as matching target-language
items to the learner's selected support-language items. One matching screen is
one question, drag is optional, an accessible two-stage selection path is
mandatory, and any number of wrong selections on that screen may cost at most
one unit of energy. Correctness, score, energy, attempt facts, and outbox data
remain server-authoritative.

The reviewed workbook has no Type-D record type. It contains `Kelime` rows and
an `Eşleştirme Grubu` column, while `Eşleştirme` exists only as a test-mode
value. Its groups contain two, four, or six word pairs. Some group labels cross
the workbook's current resolved test boundaries, and the sources do not say
whether grouped words in a mixed test become Type A, Type D, or both. They also
do not define whether a client submits individual pair guesses or one complete
mapping.

The frontend architecture says a correct pair closes, but the higher-authority
master requirement says the screen is one question and applies the general
per-`questionRevision` scoring policy. Treating each pair as a separately scored
command would invent partial-question state, repeated energy semantics, and
mastery behavior that the sources do not define.

## Decision

### Canonical runtime mapping

| Boundary | Value |
| --- | --- |
| Workbook source material | `Kelime` rows plus `Eşleştirme Grubu` |
| Workbook/test mode | `Eşleştirme` |
| PostgreSQL question revision | `question_type = 'D'` |
| API and mobile domain | `MATCHING` |
| Answer fact kind | `MATCHING` |
| Runtime policy | `matching-v1` |

One immutable Type-D question revision owns between two and six ordered authored
pairs. This bound covers every whole group observed in the reviewed workbook,
keeps the mobile interaction and answer body bounded, and is part of
`matching-v1`; supporting a larger group requires a new policy/revision rather
than reinterpreting existing history.

Each pair stores an opaque target-item UUID and target-language display text.
Each declared course support language has a complete immutable translation row
for every pair, with its own unrelated opaque support-item UUID and display
text. Public item IDs are independently generated random UUIDv4 values; they are
never derived from text, pair identity, insertion order, a shared namespace, or
one another. A checked-in local fixture may use independently pre-generated
fixed UUIDv4 literals, but not name-based or sequential UUIDs.

A Type-D revision cannot activate unless every course support language has
exactly one translation for every pair. The learner's active enrollment row is
selected and locked inside the attempt-start transaction, and its support
language is pinned onto the test attempt atomically. Payload construction,
idempotent attempt replay, answer evaluation, feedback, and reconciliation all
use that pinned language even if an enrollment preference later changes.

Within each displayed side, item IDs and normalized display labels must be
unique so a learner never sees an ambiguous bijection. `matching-label-v1`
uses the ADR-008 safe-character, NFC, Unicode-whitespace, and locale-pinned
uppercase-then-lowercase steps with the item's target or support BCP 47 language;
the immutable display spelling remains unchanged. The pair relationship is
server-only authored data. A group label is provenance, not a public answer
identifier or a globally scoped domain identity.

Matching pairs and translations use composite foreign keys that bind the child,
question revision, course, and support language identities. Inserts require a
DRAFT parent; updates and deletes are rejected as append-only content. A
deferred end-of-transaction validator covers Type-D activation, pair or
translation insertion, course-support-language mutation, and course/release
activation. It proves the two-to-six bound, zero options, per-side identity and
label uniqueness, and complete translations for every declared language. These
operations take the parent course and question-revision locks in a fixed order,
so a concurrent language insertion and revision activation cannot create an
incomplete ACTIVE revision. Adding a support language while an existing ACTIVE
Type-D revision lacks that language therefore fails closed.

Types A/B/C keep their existing nonblank prompt and authored-answer shapes. A
Type-D revision stores both legacy `prompt` and `correct_answer` as null; it
must never use a sentinel prompt or dummy answer. A Type-D attempt question has
a required null `prompt`, an empty `options` array, and separate `targetItems`
and `supportItems` arrays of equal size in the attempt's pinned support
language. Non-D questions carry empty matching-item arrays. The attempt response
also returns that pinned canonical `supportLanguage`. The client never receives
a pair ID, shared ordering key, correct flag, or other field that links the two
sides.

Question order remains deterministically derived from the attempt seed. Type-D
item order uses the byte-exact, versioned `matching-order-v1` algorithm instead
of platform `hashCode`, XOR seed mixing, or an unspecified PRNG. For each item,
the server hashes the following field sequence with SHA-256: the ASCII policy
domain, the signed attempt seed as eight-byte big-endian two's-complement data,
the RFC 4122 16-byte question-revision UUID, the ASCII side domain (`target` or
`support`), the canonical pinned support-language UTF-8 bytes, and the RFC 4122
16-byte item UUID. Every field is preceded by its unsigned 32-bit big-endian
byte length. Items are sorted by unsigned digest bytes and then by unsigned UUID
bytes as a collision tie-break. Distinct side domains and unrelated item IDs
produce independent deterministic orders.

No positional relationship is promised or signalled: a coincidental same-row
pair is possible and carries no information. Conditioning the support order to
avoid correct same-row pairs is forbidden because that negative constraint
would leak the complete answer for a two-pair group and partial answer
information for larger groups. Attempt replay reconstructs the same orders from
the persisted seed and policy; an ordering change requires a new policy and new
question revisions rather than reinterpreting an existing attempt.

### One complete mapping and authoritative result

The learner creates tentative pairs locally through two-stage selection and
submits one complete one-to-one mapping. `SubmitAnswerRequest` gains a third
answer form, `matches`, containing one target-item ID and one support-item ID per
pair. It is mutually exclusive with `selectedOptionId` and `typedAnswer`, must
cover every server-issued item exactly once, and must contain no duplicate ID.

The backend compares the complete bijection inside the existing ADR-002 answer
transaction. The question is correct only when every submitted pair is correct.
Exactly one `answer_submission`, score calculation, attempt update, and outbox
fact is produced. An incorrect mapping is one wrong question and therefore can
produce at most one energy loss. Pair-level correctness never earns partial
score and never creates a separate energy event.

After commit, a Type-D response contains `correctMatches`, the complete correct
mapping for that submitted question, and neither `correctOptionId` nor
`correctAnswerText`. The three feedback forms are mutually exclusive. Both the
server response builder and client decoder require exact one-to-one coverage of
the target and support item IDs issued for that question. While the submitted
mapping still exists in live memory, the client may mark/close correct submitted
pairs and show the authoritative mapping, but it does not send another command
for that question in the same attempt. A later attempt uses the normal mastery
policy to recover active score.

### Idempotency and privacy

The submitted mapping is canonicalized as an unordered set sorted by the
unsigned RFC 4122 16-byte target UUID under `matching-v1`. The answer fact
stores no submitted pair list or correct-pair count. It stores a random 16-byte
salt, a canonical replay-key version, an identity-bound HMAC-SHA-256 token, and
the unavoidable question-level `is_correct` fact. The 32-byte HMAC key remains
outside PostgreSQL.

The exact HMAC input is the following ordered sequence: the ASCII
`kelimio.matching-replay.hmac-sha256-v1` domain, salt, ASCII matching policy,
ASCII key version, user/attempt/submission/question-revision UUIDs, pinned
support-language UTF-8 bytes, unsigned 32-bit big-endian pair count, and each
canonical target UUID followed by its submitted support UUID. Every field other
than pair count is preceded by its unsigned 32-bit big-endian byte length; UUIDs
use RFC 4122 16-byte form. Including both the secret key and framed key version
prevents a token from being reinterpreted across rotation versions. Fixed
cross-order vectors prove that array reordering replays while any changed key,
version, salt, edge, language, or command identity changes the token.

The runtime configuration supplies one canonical active key version and a
comma-separated ring of one to eight unique version-to-key entries. Versions
are one to 32 lowercase ASCII letters, digits, `.`, `_`, or `-`, beginning with
an alphanumeric character; each key must Base64-decode to exactly 32 bytes. The
active version must be present. Missing or malformed configuration fails startup
in every environment. Production and staging values belong in the approved
secret store; Compose may use only its explicitly public local-development key.

A retired verification key must remain in the ring for as long as any answer
fact carrying its version remains replayable. Removing it turns replay into a
sanitized configuration failure, never an idempotency conflict. The eight-key
bound is deliberate: before adding a ninth version, a new ADR, migration, and
key-provider/retention design must be accepted. Raw mappings do not exist, so an
old token cannot be re-keyed in place.

The structural command fingerprint contains only stable command identity and
the `MATCHING` answer kind. Replay selects the verification key by the stored
version, recomputes the salted HMAC token, and compares it in constant time. The
same complete mapping replays the committed result; a different mapping under
the same submission or idempotency identity conflicts without creating another
fact, score, energy change, attempt update, or outbox event.

This HMAC is a database-confined replay equality token, not anonymity or
full-compromise protection. A database-only attacker without the external key
cannot enumerate candidate mappings from the token. The authoritative
`is_correct` fact remains necessary for score/projection truth and inevitably
reveals whether the whole mapping was correct. `is_correct = true` identifies
the submitted mapping as the authored mapping for any group size; for a two-item
complete bijection, `is_correct = false` identifies the only possible swapped
mapping. If both the database and key store are compromised, this design does
not prevent enumeration; incident response and key rotation are still required.

Submitted mappings, replay key/version, HMAC token, salt, and authored pair
relationships are forbidden from logs, analytics, metrics, problem details,
attempt/outbox payloads, and durable mobile recovery. Request, feedback,
configuration, domain, and persistence diagnostic strings redact matching
selections, correct mappings, and replay evidence. POST and ownership-scoped
reconciliation responses use `Cache-Control: no-store` and are the only client
responses that may contain the post-commit correct mapping.

### Mobile interaction and recovery

The mandatory interaction is accessible two-stage selection: select one target
item, then one support item. Drag may be added later but is not required and
must never be the only path. Tentative assignments are visually and
semantically distinct from server-confirmed correctness. Controls remain at
least 48 dp, item text follows its own first-strong direction, selection state
survives scrolling, and the layout must pass RTL, screen-reader, keyboard/focus,
dynamic-text, and narrow-screen tests.

The mobile state machine submits only a complete bijection and finalizes colors
or correctness only after the server response. A retryable live failure may
retain the tentative mapping in memory only: it first reconciles, then may
resend that exact mapping with the same submission ID when no committed result
exists. A 413 or semantic-validation rejection clears the board while retaining
the reserved submission ID. A conflict reconciles before any new command.

Process recovery stores only the answer kind, submission identity, and normal
attempt position; it does not persist the learner's mapping or correct mapping.
If reconciliation finds no committed result, the app presents an empty matching
board with the same reserved submission ID. If reconciliation finds a committed
result after the process lost its tentative mapping, feedback intentionally
degrades to the authoritative full mapping and question result; the client
cannot label which old tentative pairs were correct and must not reconstruct or
echo them. Ambiguous failures first use the ownership-scoped recorded-answer
lookup.

### Workbook and local-starter boundary

This ADR does not enable production workbook matching composition. ADR-006's
fail-closed `Eşleştirme` preview rule remains in force until Phase 3 separately
defines group-label scope/normalization, grouping before or after test
allocation, cross-test labels, and mixed-mode conversion without losing or
duplicating source rows.

Type-D content activation is limited to the local-development starter path in
this milestone. Production activation remains a release blocker until the
workbook semantics above and a stored minimum-client/capability gate are
implemented; documentation alone is not treated as an enforceable compatibility
gate.

The local-only starter course may add one Type-D question from the unambiguous
four-row `EV` group in `Giriş Seviyesi`: `Pencere`/`Window`, `Kapı`/`Door`,
`Masa`/`Table`, and `Sandalye`/`Chair`. Those rows are contiguous, share one
unit/topic/group, and remain within one current automatic mixed test. A new
origin key creates immutable starter release v4; earlier starter releases are
not mutated. This bounded development fixture does not claim to be the
production import algorithm.

## Data and compatibility impact

- A forward-only V7 migration expands question and answer kinds to D/MATCHING,
  makes the legacy prompt/answer columns conditionally nullable, adds immutable
  matching-pair/translation rows and conditional revision constraints, pins
  enrollment support language on attempts, and initially adds salted unkeyed
  matching replay evidence that V8 replaces before release. Existing A/B/C
  content and answer facts remain unchanged. Every existing attempt is
  backfilled from its unique owning
  enrollment; migration fails closed if any attempt lacks exactly one such row,
  and never substitutes a course default. This backfill is authorized only by
  the repository's preproduction state and the absence of any supported
  application operation that changed enrollment support language before V7. An
  environment outside that precondition must not apply the automatic backfill;
  it requires an audited per-attempt mapping or explicit disposal of
  nonproduction attempt data. Forward creation locks the active enrollment row
  and pins its language atomically. The pinned column is covered by a composite
  course-language foreign key and the attempt-snapshot immutability trigger.
- V7 replaces nullable revision-content comparisons with `IS DISTINCT FROM`,
  includes every new policy field, and validates Type D's null legacy fields and
  complete children at activation and deferred commit.
- V8 is a mandatory pre-release security correction. V7 is left byte-for-byte
  intact because it was already applied to a retained local database. V8 fails
  closed if any V7 `MATCHING` answer fact exists: the raw mapping was never
  stored, so an unkeyed digest cannot be converted safely. With that precondition
  satisfied, V8 drops `matching_correct_pair_count`, adds
  `matching_replay_key_version`, and replaces the current evidence-shape and
  answer-fact validation rules. Existing A/B/C facts remain unchanged.
- OpenAPI, backend, generated clients, and mobile support ship together. Older
  clients fail closed on `MATCHING`; no production release may activate Type-D
  content before the supported-client gate is met.
- Correct mapping feedback is transaction-specific answer-key material and
  follows the same no-store, redaction, and reconciliation boundary as ADR-008.
- The local Android acceptance path grows from seven to eight questions; an
  all-first-correct run yields 8/8 and 480/480 at the next projection version.

## Consequences

- One screen remains one question and reuses the proven authoritative scoring,
  energy, idempotency, append-only fact, and outbox transaction.
- The API cannot leak a matching answer through shared pair IDs or correlated
  ordering before submission.
- Pair-level partial credit and pair-by-pair server commands are intentionally
  unsupported by `matching-v1`.
- Matching replay remains available across key rotation only while every
  referenced verification key is retained; exhausting the eight-key ring is an
  architecture/migration gate, not permission to evict a live historical key.
- Production Excel composition remains visibly blocked instead of guessing how
  cross-test or mixed-mode groups should behave.
