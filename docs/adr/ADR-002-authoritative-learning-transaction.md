# ADR-002: Authoritative Learning Transaction and Asynchronous Projections

- Status: Accepted
- Date: 2026-07-21
- Last amended: 2026-08-01

## Context

The backend source describes one answer transaction that evaluates correctness and writes attempt, score, energy, and outbox data. Its initial event catalog also shows `AnswerRecorded` consumed by a Scoring module, which could be read as delayed score authority. That interpretation would make the response race an asynchronous consumer and risk double awards, temporary contradictory energy/score, or eventual-consistency failures in the core learning rule.

One answer also crosses logical Learning Session, Scoring, Energy, and Outbox module boundaries. A modular monolith allows one database transaction, but its owner and future extraction seam must be explicit.

## Decision

The `learning-session` application service owns the online answer command and orchestrates one PostgreSQL transaction. It calls synchronous application/domain interfaces owned by scoring and energy; it does not reach into their repositories directly.

Within the transaction:

1. authenticate and authorize the enrollment/entitlement;
2. lock or version-check the attempt, question revision, mastery, and free-course energy rows needed for concurrency safety;
3. verify the attempt is open, the pinned question revision belongs to it, sequence is valid, and `submissionId` has not been processed;
4. evaluate correctness using server-only answer data;
5. calculate and persist the authoritative score delta and minimal current mastery state;
6. lazily regenerate and, for a wrong free-course answer, atomically change authoritative energy;
7. append `question_attempt`, `score_event`, `energy_event` when changed, and the idempotency result;
8. append outbox records containing stable fact/event IDs and the calculated result;
9. return correctness, score delta/current active score, energy, and interruption state from committed authoritative data.

The durable facts and command result are synchronous. Asynchronous consumers may build or refresh:

- test/unit/course progress projections;
- profile and verified leaderboard projections;
- streak/notification effects after test completion;
- analytics, fraud signals, and warehouse exports;
- cache invalidation.

An `AnswerRecorded` consumer must never calculate a second authoritative award. If the event catalog retains a Scoring consumer label, that consumer means score projection/reconciliation only. `ScoreChanged` references the already-persisted score event.

Every consumer is idempotent and handles at-least-once delivery. PostgreSQL is the source; Redis and projections can be deleted and rebuilt.

### Projection freshness and failed deliveries

`updating=true` means that the returned values are the last completed
projection and unresolved authoritative facts still exist. This includes both
deliveries that are pending/retryable and deliveries moved to `DEAD` after the
bounded worker retry policy. A dead delivery must not be treated as
`updating=false`, because doing so would present known-stale values as final.

The initial API contract deliberately does not expose internal delivery state.
Mobile polls with bounded backoff; if the projection remains updating after the
budget is exhausted, it replaces the updating indicator with a retryable error
and an explicit retry action. It must not leave a permanent spinner. Operations
must alert on dead deliveries and replay the delivery or rebuild the projection
from PostgreSQL facts. A future public `failed` projection status requires a
versioned contract change and an ADR update.

## Module and extraction consequences

- Logical module ownership remains strict even though the command uses one physical database transaction.
- Unique constraints include the submission identity in its user/attempt scope and store enough response material to return the prior result for an identical retry; the same key with a different body returns conflict.
- Row locks/optimistic versions protect concurrent devices. The score policy is property-tested independently and invoked synchronously.
- Extracting Learning, Scoring, or Energy into separate services is forbidden without a new ADR that replaces the transaction guarantee with a proved protocol, reconciliation model, user-visible latency budget, and rollback path.

## Data and migration impact

Initial migrations require append-only attempt/score/energy/outbox tables, idempotency storage, minimal mastery/energy current state, foreign keys to immutable revisions, and projection version/rebuild metadata. There is no existing production data migration.
