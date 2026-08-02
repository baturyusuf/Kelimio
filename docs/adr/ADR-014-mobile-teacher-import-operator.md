# ADR-014: Local Mobile Teacher Import Operator

- Status: Accepted
- Date: 2026-08-02
- Decision owners: Product owner and architecture

## Context

ADRs 010 through 013 define a local/test-only workbook intake, immutable
preview and approval, exactly-once draft commit, impact-bound publication, and
release-aware reprojection path. Those services were operable through the
acceptance runner, but the Flutter application had no teacher-facing operator.

The mobile boundary must not weaken the backend's authority, leak bearer tokens
to presigned object-storage URLs, retain workbook content unnecessarily, or
collapse preview approval, draft creation, and publication into one ambiguous
action. A lost response must also reuse the original command identity instead
of creating a second import, draft, or activation.

## Decision

### Availability and authority

- The teacher operator is compiled into the shared Flutter application but is
  reachable only when `localDevelopmentToolsEnabled` is true.
- Production configuration continues to reject that flag. This screen is not a
  production authoring entitlement, feature flag, or authorization mechanism.
- The server remains authoritative for validation, preview contents, approval
  binding, draft creation, release impact, activation, and reprojection.
- The local screen provides no manual success, paid, ownership, or publication
  bypass.

### Workbook selection and upload

- Native file selection is behind the platform-independent `WorkbookPicker`
  interface. The Android/iOS adapter accepts `.xlsx`; the repository separately
  enforces the extension and the 25 MiB limit.
- The client reads bounded byte ranges, computes the whole-file SHA-256 and
  exact 5 MiB part declarations, and sends those declarations to the intake
  API.
- It cross-checks every returned part number, size, content-length, checksum,
  count, and expiry before uploading any byte. Any mismatch fails closed.
- Presigned `PUT` requests use a dedicated Dio client with redirects disabled.
  They contain only the required content length and checksum and never use the
  API bearer-token interceptor.
- Request/response bodies, authorization headers, presigned URLs, ETags,
  workbook names, and reviewed content are removed from escaping transport
  errors or kept out of diagnostics as applicable.

### Explicit state transitions and recovery

- Selecting a workbook reserves separate create and completion command IDs.
  An uncertain upload retry reuses both IDs and the same selected bytes.
- Processing is polled for a bounded six minutes. Retry resumes upload,
  processing, preview retrieval, or impact retrieval from the last known safe
  state.
- Preview acknowledgement only enables the digest-bound approval command.
  Approval does not create a course.
- A second acknowledgement enables exactly-once draft creation. Draft creation
  does not publish a course.
- The server-provided impact is displayed before a third acknowledgement enables
  activation. An optimistic conflict clears that acknowledgement and requires a
  fresh impact review.
- Command IDs remain in volatile controller state across uncertain responses.
  Workbook content and preview rows are not written to Drift or secure storage,
  and logout invalidates the complete authoring controller.
- ADR-015 extends this volatile flow with explicit owner-scoped, no-store import
  discovery and process-state resumption. Production authoring remains blocked
  until the applicable authorization, consent, editor-conflict, staging, and
  operational controls exist.

### Presentation

- Preview and issue results are paged. Teacher-only answer/distractor content is
  shown only after the owner-scoped no-store API returns it.
- Turkish, English, and Arabic strings, RTL direction, first-strong content
  direction, dynamic text sizing, semantic row labels, non-drag controls, and
  disabled-state confirmations are part of the local UI contract.

## Consequences

- A local Android operator can drive the real backend lifecycle without Google
  Play, AWS production deployment, or a store app record.
- The storage upload credential boundary is independent from the authenticated
  API client, reducing bearer-token and redirect leakage risk.
- The three irreversible meanings remain visibly separate and are independently
  tested.
- The guarded Android acceptance journey drives a real reviewed workbook through
  upload, private scanning, preview, all three confirmations, draft creation,
  impact review, and initial publication on a fresh Flyway V12 stack.
- ADR-015 now proves server-backed recovery after controller/process-state loss.
  Later editing, ETag conflict/diff handling, unsaved-change recovery,
  role/eligibility policy, and staging proof remain open Phase 3 work.
