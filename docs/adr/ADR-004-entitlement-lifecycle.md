# ADR-004: Store Truth and Revocable Course Entitlement

- Status: Accepted
- Date: 2026-07-21

## Context

Kelimio sells course-specific non-consumable products on Android and iOS. Some architecture diagrams call the resulting entitlement permanent, while the governing rules require refunds, voids, chargebacks, legal action, store notifications, and account changes to alter access. Treating entitlement as a permanent boolean would conflict with store truth and make reconciliation or lawful revocation impossible.

Paid access also affects unlimited energy, course downloads, existing buyers after a course is hidden, teacher earnings, and already-installed offline packages.

## Decision

### Facts and current state

- Purchase orders, verified store transactions, store-notification inbox records, entitlement events, and teacher earning/reversal events are immutable and idempotent.
- Platform transaction/original-transaction identity is unique in the correct store/account scope.
- The current entitlement row is a projection from verified facts, not the only history.
- No client callback or client-declared product/course mapping grants access.

The entitlement projection uses these access states:

- `ACTIVE`: verified access; the user may enter the course, has unlimited energy for that course, and may obtain/update an authorized offline package.
- `SUSPENDED`: temporarily blocked while store, fraud, legal, or account reconciliation is unresolved; UI offers a support/retry state and no new paid benefit is issued.
- `REVOKED`: access removed after verified refund, void, chargeback, fraud decision, account deletion, or applicable legal/policy decision.

Before successful verification there is no active entitlement. Purchase-order states such as created, pending-store, verifying, failed, or cancelled are not entitlement. Restore/reinstatement appends new verified facts and may transition the projection back to `ACTIVE`; history is not rewritten. Reason codes and effective times are mandatory.

### Activation and notification handling

- Backend creates a purchase order before the store sheet opens.
- Backend verifies the signed transaction/token with the store, validates product/course/account mapping and uniqueness, then writes `store_transaction` and `entitlement=ACTIVE` in one PostgreSQL transaction with outbox data.
- Google RTDN and App Store Server Notifications V2 enter authenticated idempotent inboxes and reconcile current state. Delivery order cannot be trusted; reconciliation can query store truth.
- Restore always re-verifies with the backend/store and never trusts a local receipt flag alone.

### Course and offline behavior

- Hiding/unpublishing a course closes new sales but existing `ACTIVE` holders retain access, matching the governing product rule.
- A safety/legal `REMOVED` state is distinct from ordinary hiding and may override access under the approved takedown policy. That detailed policy and communication path remain an owner launch action.
- Logout/account switch removes private entitlement metadata and locks paid local content.
- `SUSPENDED` or `REVOKED` prevents new package URLs/updates and locks the installed paid package at the next entitlement check. Offline revocation cannot be instantaneous; each package carries `expires/checkAfter` and the owner must approve the maximum offline grace period before launch.
- Encryption may deter casual extraction but is not treated as DRM or as the source of entitlement security.

### Money consequences

- Entitlement activation and teacher earning facts reference the same verified store transaction but remain separately auditable.
- Refund/chargeback appends entitlement revocation and earning reversal facts; it never edits the original transaction/earning.
- No payout occurs without real KYC/KYB and provider state.

## Consequences

- “Non-consumable” means no planned expiry under normal store truth, not irrevocable access under every future event.
- Mobile/web require pending, verifying, suspended, revoked, restore, and support states.
- Initial data model needs immutable provider inbox/transaction/event tables, a current entitlement projection with reason/effective time/version, reconciliation checkpoints, and append-only earning/reversal references.
- Store catalog provisioning, legal takedown behavior, and maximum offline grace remain explicit owner/launch gates rather than hidden code defaults.
