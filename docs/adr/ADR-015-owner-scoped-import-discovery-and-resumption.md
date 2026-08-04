# ADR-015: Owner-Scoped Import Discovery and Resumption

- Status: Accepted
- Date: 2026-08-02
- Decision owners: Product owner and architecture

## Context

ADR-014 deliberately kept workbook bytes, reviewed rows, and command identifiers
out of durable mobile storage. That protects private authored content, but a
controller or process restart previously left no safe way to find a server-side
import that had already reached preview, approval, draft commit, or publication.
Persisting the workbook or reconstructing success on the client would weaken
the server-authoritative lifecycle.

The import module also cannot determine publication by querying the
course-publication module's tables. A resumed committed import must nevertheless
distinguish an unpublished draft from a release that was already activated, or
the UI could offer an invalid second publication path.

## Decision

### Server discovery boundary

- The authenticated API exposes a no-store, owner-scoped list of import status
  resources ordered by immutable `(created_at, id)` positions.
- Pagination uses a versioned, HMAC-authenticated, owner-bound keyset cursor.
  Invalid, modified, cross-owner, oversized, or malformed cursors fail as not
  found and never fall back to an unscoped list.
- The response reuses the redacted status projection. It never exposes owner
  identifiers, object-store coordinates, multipart identifiers, scanner output,
  workbook rows, answer content, internal retry details, or upload credentials.
- Listing is bounded to fifty items per request and uses the existing
  owner/creation index. PostgreSQL remains the durable source of truth.

### Publication evidence and module ownership

- The course-publication module owns a narrow application lookup for the latest
  activation of one owner, course, and immutable release.
- The import module consumes that interface; it does not read publication tables
  or repositories. A committed import status may include only the release ID,
  operation, activation time, and reprojection status needed for recovery.
- Activation evidence is recovery information for the author UI. It is not an
  entitlement, payment, catalog-visibility, or learner-access proof.

### Mobile recovery behavior

- Import discovery is always explicit and network-backed. No workbook bytes,
  preview rows, issue text, cursor, import status, or authoring command ID are
  written to Drift, secure storage, or analytics.
- Selecting a discovered item refreshes it through the owner-scoped status API
  before any action. Processing may be polled; preview and validation results
  are reloaded from their no-store owner APIs.
- `UPLOADING` cannot resume after process death because the client intentionally
  no longer holds the selected bytes. The UI requires a new file selection and
  a new import instead of guessing upload completion.
- Approval, draft commit, and activation command IDs are generated only for a
  transition not already represented by server truth. Existing approval,
  commit, or activation facts are never synthesized locally.
- A committed import without activation resumes at the server-calculated impact
  gate. A committed import with activation evidence is displayed as published
  and cannot expose another activation control.
- Logout continues to invalidate all volatile authoring state.

## Consequences

- Losing Flutter controller or Android process state no longer loses a completed
  upload, preview, approval, or unpublished draft.
- Recovery does not expand local retention of private workbook content and does
  not create a permissive success fallback.
- The combined real-service Android journey deliberately discards controller
  state after preview, discovers and resumes the import, publishes it, discards
  state again, and verifies that server activation evidence disables a second
  publication path.
- Production authoring remains blocked on teacher eligibility and consent,
  production IAM/storage/scanner evidence, editor conflict handling, staging
  proof, and the other open release gates. This ADR does not make the local
  operator production-authorized.
