# ADR-005: First-Login Profile Setup and Identity Linking Boundary

- Status: Accepted
- Date: 2026-08-01
- Decision owners: Product owner and architecture

## Context

An authenticated OIDC subject currently creates an application user lazily with
fallback language values. That is sufficient to bind server facts to a stable
subject, but it is not evidence that the person explicitly selected application,
learning, and support languages. Routing directly to learning screens would make
those provisional defaults look like completed user choices.

The owner also requires email/password and Google sign-in to reach one profile
when they belong to the same person. Email strings alone are not proof of account
ownership, and unverified or recycled addresses make backend auto-linking unsafe.

## Decision

### Provisional user and setup gate

- A valid OIDC subject may create one provisional `app_user` row so requests have
  a durable server identity.
- `GET /v1/me` reports `profileSetupStatus=REQUIRED` until explicit setup is
  committed. Provisional defaults are suggestions, not accepted preferences.
- Catalog, enrollment, learning, energy, progress, and local development content
  endpoints require `profileSetupStatus=COMPLETE` on the backend. Mobile routing
  mirrors this rule but is not its authority.
- Profile setup is a one-time, idempotent command. It locks the user, records the
  canonical request fingerprint, increments the profile version, writes an
  append-only sanitized profile event, and appends an outbox fact in one
  PostgreSQL transaction.
- A retry with the same key and canonical request returns the committed profile.
  Reusing the key for different data, or using a new key after completion, fails
  with conflict.

### Language and time-zone semantics

- Application locale, active target language, preferred support language, and
  time zone are separate fields.
- This client release supports `tr`, `en`, and `ar` application locales. Target
  and preferred support languages use canonical BCP 47 tags and must differ.
- Preferred support language is only a default. The support language stored on an
  enrollment remains course-scoped and server-authoritative.
- Initial setup normalizes display names with Unicode NFKC, collapses whitespace,
  enforces the 80-character limit, and rejects control and bidirectional override
  characters. Provisional claim-derived names follow the same safety policy and
  fall back to a neutral value; unverified email is not a display-name source.
  Time zones must be a named identifier from the backend's IANA-compatible zone
  database, or `UTC`; raw numeric/GMT fixed offsets are rejected.

### Identity linking and email

- The OIDC subject is the application identity key. The backend never merges
  users merely because email strings match.
- Email is stored only when the token asserts `email_verified=true`; it remains
  private account metadata and is not returned by the profile DTO.
- OIDC subject and provider username remain server-side identity metadata and
  are not returned by the profile DTO.
- Email/password and Google identities may reach one application subject only
  through the approved managed OIDC broker's verified linking flow, including
  ownership proof and reauthentication where required.
- Until that provider flow exists and passes integration/security tests, account
  linking remains a release blocker. No manual database merge or permissive
  fallback is allowed.

### Legal acceptance boundary

Completing profile setup does not represent acceptance of terms, privacy,
community, child-safety, marketing, analytics, or advertising consent. Those
records require approved versioned text and separate auditable consent facts.

## Consequences

- Existing rows remain setup-required after migration; fallback data is not
  silently promoted to an owner-approved preference.
- The first learner API call after authentication is profile discovery/setup.
- Profile setup facts contain changed field names and versions, not email or raw
  user-entered values.
- Local Keycloak may exercise verified-email registration through Mailpit, while
  production identity/provider selection and secure Google linking remain open.
