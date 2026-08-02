# ADR-010: Import Intake, Artifact Provenance, and Approval Lifecycle

- Status: Accepted
- Date: 2026-08-02
- Decision owners: Architecture and product implementation
- Partially supersedes: ADR-006 intake activation/deferred-provider portion for
  local/test approval-only import exposure
- Extended by: ADR-011 for a separate local/test idempotent unpublished-draft
  commit; approval itself remains side-effect-free

## Context

The governing master requirement defines a mobile-to-S3 Excel upload, malware
scan, isolated parse, preview, owner approval, immutable archive, and later
single course-creation commit. ADR-006 already fixes the untrusted XLSX parser
boundary and the `xlsx-v1` limits, but it deliberately leaves upload sessions,
scanner integration, durable job state, artifact provenance, and approval for a
later milestone.

This ADR partially supersedes only ADR-006's intake activation and deferred-
provider restriction: local and test may now expose the real approval-only
workflow described here, with no course commit or publication side effect.
ADR-006's production commit, publication, content-semantics, and release gates
remain in force.

The current content schema cannot losslessly commit the reviewed workbook and
production Type-D group allocation is still intentionally unresolved. Exposing
a course-creation success path now would therefore either lose source content
or weaken the fail-closed Type-D rule. The safe next vertical slice ends at an
owner approval fact and creates no course or release.

S3, SQS, and ClamAV are external side effects. A request transaction cannot
atomically update PostgreSQL and those services. The workflow must remain
correct under duplicate or reordered queue delivery, expiring upload URLs,
worker crashes at every boundary, and an object being overwritten after upload.

## Decision

### Scope and runtime separation

- The authenticated API creates and completes upload sessions, returns
  owner-scoped status/preview/report data, and records approval commands. It
  never downloads, scans, opens, or parses workbook bytes.
- A separately started `worker` runtime is the only application runtime that
  downloads import objects, talks to ClamAV, invokes `SecureXlsxReader`, builds
  the deterministic preview, or writes archive artifacts.
- PostgreSQL is the job and state source of truth. A transactional outbox is
  the only path from accepted API state to SQS. SQS contains opaque import and
  event identifiers only and is an at-least-once wake-up mechanism, never the
  authoritative job record or a source of scanner verdicts.
- This milestone ends at an append-only approval fact. No endpoint, worker, or
  fallback may create a `course`, content revision, or course release from an
  approved import until the complete content schema and Type-D conversion gate
  are implemented under ADR-003 and ADR-009.

### Upload session and exact-object binding

- A completed-profile user owns an import session. Until approved legal/UGC
  consent versions and author-eligibility policy exist, production enablement
  remains a release blocker; local real-service testing does not close it.
- Create is idempotent and accepts only a basename ending in `.xlsx`, the exact
  XLSX media type, a byte count from 1 through 25 MiB, and a lowercase whole-file
  SHA-256 assertion. Object keys are server-generated from opaque identifiers
  and never derived from the filename. The display filename is normalized to
  Unicode NFC and rejects controls, bidi overrides/isolates, zero-width/default-
  ignorable spoofing characters, path separators, drive/UNC syntax, and outer
  whitespace before it is stored or returned.
- The bounded `xlsx-v1` file is uploaded directly with a resumable S3 multipart
  session. Parts are fixed at 5 MiB except for the final part, consecutive, and
  no more than five. The API issues short-lived presigned `UploadPart` URLs for
  the exact upload ID, key, part number, and expected part length. The client
  never receives AWS credentials.
- `CreateMultipartUpload` selects S3 `ChecksumAlgorithm=SHA256` and the
  supported composite checksum mode before any URL is issued. Every presigned
  part binds its stored SHA-256 header, and `CompleteMultipartUpload` sends the
  same checksum for every consecutive completed part. A syntactically present
  checksum header without S3 checksum validation is not accepted as evidence.
- Completion is idempotent and accepts exactly the expected consecutive part
  descriptors plus the same whole-file SHA-256 assertion. Part sizes and total
  size come from the immutable create command and are rechecked against S3. The
  backend completes the multipart upload, performs `HeadObject`, and records the
  resulting nonblank S3 `VersionId`, byte count, checksum metadata when
  available, and ETag. ETag is an opaque transport value and is never treated as
  a content hash.
- Every later `HEAD`, `GET`, and `COPY` names the recorded bucket, key, and
  `VersionId`. Upload-part URLs become unusable when their upload ID is
  completed or aborted. A missing version ID, size mismatch, missing object,
  ambiguous part list, or S3 error does not enqueue processing.
- Every session uses a unique key that is never reused. If S3 completed the
  multipart object but the API lost the success response before persisting its
  `VersionId`, retry must not start or accept another upload. It first observes
  that the upload ID no longer exists, then uses the unique key's version list
  and `HeadObject` to require exactly one non-delete version created for that
  session with matching size, server-set metadata, and S3 checksum. Zero or
  multiple candidates fail closed for reconciliation. Only that recovered
  version can be recorded and enqueued. Where the selected S3 API supports a
  conditional multipart completion, the API also uses the equivalent of
  `If-None-Match: *`; the unique-key reconciliation rule remains mandatory.
- Completed-part evidence distinguishes `S3_VERIFIED` from
  `EXACT_OBJECT_RECOVERY`. A normal successful completion records the printable
  part ETags that S3 accepted. Lost-response reconciliation cannot ask S3 to
  revalidate the retry command's client-supplied part ETags, so recovered rows
  store no part ETag and instead record `EXACT_OBJECT_RECOVERY`; authority comes
  from the unique exact object version, composite checksum/part count, immutable
  declared part hashes, byte size, and server-set metadata. Unverifiable retry
  ETags are never persisted as authoritative facts.
- The client SHA-256 is only an assertion. The worker streams the accepted
  object once under the byte/deadline limit, computes SHA-256 and size itself,
  and must match both before scanning can succeed.

The master describes multipart/resumable upload while S3 normally recommends
multipart only for larger files. This decision keeps the explicit resumability
requirement even under the 25 MiB cap. The fixed five-part maximum bounds API
and mobile complexity and is part of `xlsx-v1`; changing it requires contract,
load, retry, and integrity evidence.

### State, leases, events, and retries

- The mutable import summary uses a versioned compare-and-set transition and a
  bounded worker lease. The initial states are `UPLOADING`, `QUEUED`,
  `PROCESSING`, `PREVIEW_READY`, `VALIDATION_FAILED`, `MALWARE_REJECTED`,
  `PROCESSING_FAILED`, `EXPIRED`, and `APPROVED`.
- Forward transitions require their durable prerequisite facts. A processing
  retry returns to `QUEUED` only with an incremented attempt count
  and stable failure code. Terminal states cannot return to a success path.
- Every accepted transition also writes an append-only import event. Artifact,
  scan, preview, validation, archive, and approval facts are append-only and
  database constraints prevent a second conflicting fact for the same stage.
- The import queue has a visibility timeout greater than the ADR-006 six-minute
  worker deadline, with a bounded retry count and DLQ. The database lease/token
  fences a stale worker even if SQS visibility expires. Duplicate delivery and
  a crash after an S3 side effect but before its database fact are reconciled by
  deterministic keys, exact-version reads, and idempotent fact insertion.
- Expired incomplete sessions are marked `EXPIRED` and their multipart upload
  is aborted idempotently. Scanner/storage/parser failures expose only stable
  error codes; retry exhaustion records `PROCESSING_FAILED` and retains DLQ evidence.

### Malware, archive, and parser boundary

- ClamAV is reachable only from the worker network in local and deployed
  environments. The client uses bounded connect/read/stream/deadline settings
  and the INSTREAM protocol. Only an exact `OK` response with an accepted engine
  and non-stale signature-database identity is `CLEAN`.
- `FOUND` records `MALWARE_REJECTED`. Timeout, EOF, malformed/unknown response,
  `ERROR`, unavailable scanner, or unacceptable/missing definition identity is
  a fail-closed processing failure and never invokes the parser.
- A clean scan fact binds the accepted quarantine object version, recomputed
  source SHA-256 and size, and sanitized scanner engine/signature identity. A
  verdict cannot be reused for any other object version or digest.
- The worker copies the exact clean source from a private versioned quarantine
  bucket into a distinct private versioned archive bucket. Archive keys are
  deterministic inside `ownerId/importId/artifactKind` and include the content
  digest; cross-owner or cross-import content deduplication is forbidden. The
  worker then reads the exact
  archive version and verifies size and SHA-256 again. Only that verified
  archive version is passed to the ADR-006 reader and orchestrator.
- Preview facts and validation-report artifacts are deterministic and content-
  addressed. The preview is an append-only PostgreSQL fact bound by its SHA-256
  digest; validation-report database facts store the exact versioned S3 object
  identity and digest. Local S3 versioning and application-level write-once
  checks prove identity and retry behavior, but do not claim production WORM evidence.
  Production Object Lock/KMS/retention/legal-hold policy remains an owner and
  launch gate.

### Preview and approval binding

- Status, preview, and report reads are owner-scoped. Absence and cross-owner
  access are indistinguishable. Responses use `Cache-Control: no-store`, are
  bounded/paged, and expose no bucket name, object key, presigned URL, upload ID,
  object version, raw ClamAV response, or internal exception text.
- Preview content is returned only to its owner. Logs, metrics, audit events,
  outbox payloads, and queue messages contain identifiers, counts, state names,
  and stable codes, not filenames, workbook cell text, source hashes, report
  messages, URLs, or storage/scanner internals.
- Preview/report cursors are opaque and tamper-evident (or server-side opaque
  handles) bound to owner, import, immutable preview/report identity, and row
  position. They never encode workbook text or storage coordinates. A forged,
  cross-owner, or stale-preview cursor is rejected without revealing whether
  another owner's import exists.
- A valid preview fact binds the import and owner IDs, accepted quarantine and
  verified archive artifact identities, source SHA-256 and size, scan fact and
  sanitized engine/signature identity, parser/rules version, allocation digest,
  complete-preview digest, and validation-report digest using a versioned,
  length-framed canonical SHA-256 encoding.
- Approval requires an idempotency key and the current approval-binding digest.
  The backend locks the owner-scoped `PREVIEW_READY` record and appends one
  approval fact for that exact tuple. An identical retry returns the existing
  result. A stale digest, changed command, concurrent conflicting approval, or
  non-valid preview returns conflict and creates no side effect.
- Approval does not imply publication, legal review, sale readiness, or course
  creation. There is deliberately no import commit endpoint in this milestone.

### Configuration and deployment boundary

- AWS SDK for Java v2 is exact-version pinned and S3/SQS clients use normal AWS
  credential-provider behavior. No access key is accepted through an API,
  stored in PostgreSQL, or included in a mobile binary.
- Local Compose supplies explicitly local credentials and real LocalStack S3
  and SQS services. Staging/production require private versioned quarantine and
  archive buckets, encryption and least-privilege API/worker roles, a dedicated
  queue/DLQ, private ClamAV or an approved malware service, and approved
  retention/definition-freshness policies. Missing or unsafe configuration
  fails startup or exposes `configuration_required`; it never reports success.
- The API role can initiate multipart upload, presign parts, complete/head the
  accepted object, and abort its own expired sessions. It cannot read workbook
  bodies or write scanner, archive, validation-report, or preview facts. It can
  append only the owner-scoped approval fact after those worker facts satisfy
  the database provenance gates. The worker can read exact quarantine versions
  and write deterministic archive/validation/preview facts but cannot issue
  upload URLs or approve imports. Production delete/retention-bypass permissions
  are outside both runtime roles.

## Data and migration effect

The next migration adds an owner-scoped import summary with optimistic version,
lease, attempt, expiry, and exact accepted-object fields; append-only import
events; artifact, scan, preview, validation, and approval facts; and constraints
and triggers enforcing allowed transitions and immutability. Completed-part
facts add an evidence-source discriminator and make ETag nullable only for the
`EXACT_OBJECT_RECOVERY` case; this migration creates the table and therefore
requires no backfill. It does not expand the course/revision schema or write any
course content.

An existing database migrates in place. Existing course, learning, score,
energy, outbox, and projection facts are unchanged. Migration rehearsals must
prove both an empty database and the retained V8 upgrade path.

## Consequences

- The real untrusted-file boundary can be exercised locally through PostgreSQL,
  LocalStack, SQS, ClamAV, and the isolated parser without inventing a course
  commit or weakening unresolved content semantics.
- Exact S3 versions and recomputed hashes prevent a mutable-key or client-hash
  assertion from changing what was scanned, previewed, archived, or approved.
- At-least-once delivery and worker crashes may repeat work but cannot produce a
  second authoritative fact or advance a job without its prerequisites.
- Mobile teacher import UI and the later commit/publish transaction can consume
  a stable owner-scoped contract, but they remain separate milestones.
- Production author eligibility/UGC consent, retention/Object Lock/KMS, scanner
  definition policy, AWS IAM/networking, Type-D group conversion, complete
  content persistence, and publication remain explicit launch blockers.
