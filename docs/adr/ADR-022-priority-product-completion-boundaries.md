# ADR-022: Priority product completion boundaries

- Status: Accepted
- Date: 2026-08-27

## Context

Kelimio has production identity, learning, energy, initial XLSX import, immutable releases, and several server-side capabilities that are not yet reachable through the versioned API contract and mobile application. The priority completion scope is teacher course management and full non-XLSX editing, learner discovery and progress surfaces, private-by-default public profiles and leaderboards, scoreless offline practice, account lifecycle controls, and notification preferences.

ADR-003 makes PostgreSQL authoritative for scored learning. ADR-004 requires immutable course releases. ADR-005 separates an initial XLSX import from later authoring. ADR-016 defines subsequent authoring and publication proof. ADR-002 forbids email-based identity merging. ADR-003 also requires offline practice to remain scoreless and never upload answers. Some provider-dependent capabilities need Google, Firebase, mail-provider, or store credentials that an AWS session cannot supply.

## Decision

1. XLSX remains an initial course-creation mechanism only. A teacher lists owned courses, opens the active immutable release in the full editor, saves an ETag-bound draft, reviews release impact, and activates it through the existing publication authority.
2. Teacher, learner, profile, offline, account, and notification operations are added to `contracts/openapi/kelimio-api.yaml` before clients consume them. Checked-in clients remain generated artifacts.
3. Catalog search and filters are server-side and cursor-bound. Invitations are opaque, expiring, revocable, single-course grants; accepting one creates or restores no entitlement beyond the invitation's declared free/private-course access.
4. Learning history, streaks, completion, and rankings are projections rebuilt from append-only authoritative facts. Public profile and leaderboard participation remain disabled by default and require explicit opt-in. No private profile data is returned publicly.
5. Offline packages are immutable, checksummed release artifacts stored in the existing encrypted, versioned object store. The device verifies the package before atomically installing it, records practice only in a separate local store, awards no score or energy, never uploads offline answers as scored activity, and purges package and practice data on sign-out or account switch.
6. Account export is an authenticated, no-store portable response while the bounded beta dataset remains small; a later object export must use a short-lived, owner-bound URL. Deletion requests are auditable, revoke managed-provider sessions immediately, and may execute anonymisation only after the owner approves the retention/legal-hold policy. Provider identities are linked only by a verified managed-provider flow; email equality is never sufficient.
7. Notification preferences are authoritative per user and category. Device tokens are replaceable delivery addresses, not identity. Push and email delivery fail closed with `configuration_required` until their real providers are configured; no success fallback is permitted.
8. Legal consent records are append-only and versioned independently from profile setup. The application may record only owner-approved document identifiers and versions; it does not invent legal text.

## Consequences

- Previously implemented full-editor and social services can be exposed after contract and authorization coverage are added.
- External provider setup remains an explicit release gate where Google/Firebase, SES production access and verified identities, or store credentials are absent.
- The mobile application can deliver all provider-independent behavior while clearly identifying unavailable delivery channels instead of appearing to succeed.
- Tests must cover optimistic conflicts, owner boundaries, privacy opt-in, cursor stability, offline non-upload, export ownership, deletion/session revocation, and notification fail-closed behavior.
