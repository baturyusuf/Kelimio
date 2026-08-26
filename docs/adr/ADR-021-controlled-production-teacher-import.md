# ADR-021: Controlled Production Teacher Import

- Status: Accepted
- Date: 2026-08-26
- Decision owners: Product owner and architecture
- Supersedes: ADR-014's local-only mobile availability rule and the temporary
  production prohibition in ADR-006, only for the controlled internal-test
  initial-course import described here
- Amends: ADR-018's on-demand import-worker design

## Context

The owner directed that the current production-backed internal Android build
must create an initial course from an owner-supplied Excel workbook. The
locally proven intake already preserves checksum-bound multipart upload,
exact-version recovery, malware scanning, deterministic preview, separate
approval/commit/publication gates, immutable releases, and owner isolation.
Production did not expose that capability because the API, mobile route,
scanner worker, separate worker identity, and deployment gate were absent.

Enabling the local-development switch in production would make the client an
authorization authority and would bypass the production eligibility and terms
boundary. Running ClamAV continuously would also conflict with ADR-018's cost
limit. Public teacher onboarding, paid marketplace behavior, moderation, and a
complete course-tree editor remain blocked by unresolved provider and legal
decisions.

## Decision

- The production feature is a controlled internal-test capability for creating
  an initial course from Excel. It is not public teacher onboarding.
- The mobile tab may be compiled into an internal-test build, but the backend
  remains authoritative. Access requires all of:
  `KELIMIO_PRODUCTION_TEACHER_FEATURES_ENABLED=true`, membership in the managed
  Cognito `kelimio-teachers` group, and acceptance of the exact required
  authoring-terms version through the versioned teacher-access API.
- The API owns upload-session creation, exact object completion, expiry,
  preview/approval/commit/publication commands, and transactional-outbox
  publication to SQS. It never parses the workbook.
- An isolated X86_64 ECS worker task consumes SQS with a separate IAM role,
  separate `kelimio_worker` PostgreSQL login, explicit import-table privileges,
  bounded CPU/memory/tmp storage, and no public ingress.
- A digest-pinned ClamAV sidecar must be healthy and use definitions no older
  than 24 hours. Scanner error, stale definitions, timeout, unknown verdict,
  or malware fails closed.
- SQS visible plus in-flight message count scales the worker service from zero
  to exactly one. Five consecutive empty minutes scale it back to zero. This
  preserves ADR-018's no-always-on-worker budget boundary.
- Quarantine and archive objects use the existing private, versioned,
  KMS-encrypted buckets. Original archive Object Lock remains controlled by the
  owner-approved retention input. API and worker S3/SQS/KMS permissions are
  separate and resource-scoped.
- The protected deployment builds immutable ARM64 API, X86_64 worker, and
  X86_64 scanner images, scans the exact digests, migrates both database roles,
  and activates teacher import only through an explicit workflow input paired
  with API promotion.
- The local single-question development editor is not exposed in production.
  Production Excel remains initial-course-only and can never update an existing
  course.

## Consequences

- An authorized owner can use the production-backed Android build to upload,
  inspect, approve, create, and publish one immutable initial course without a
  fake service or client-granted role.
- Queue arrival may take roughly one to several minutes to start a cold worker
  and fresh scanner. The mobile state is resumable and must describe processing
  rather than spinning without a bound.
- This decision does not approve public UGC, minors' publishing, moderation,
  pricing, commerce, payouts, legal text, or store release. Those launch
  blockers remain open.
- Deployment plus a real production pre-traffic workbook canary, malware
  rejection canary, worker scale-to-zero observation, and retained evidence are
  required before this implementation is considered operational.
