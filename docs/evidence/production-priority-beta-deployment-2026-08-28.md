# Production priority-beta deployment evidence — 2026-08-28

## Scope and boundaries

This record covers the guarded deployment of ADR-022's priority beta API,
PostgreSQL migrations, Cognito global-session revocation permission, offline
package access, and controlled teacher features to AWS account `923300948109`
in `eu-central-1`. It also records an internal debug-signed Android artifact for
owner device testing. It is not evidence of public/store release readiness.

## Immutable source and review

- Reviewed pull request: [#65](https://github.com/baturyusuf/Kelimio/pull/65).
- Deployed source revision: `a6bf7c2b86011b87367781e88cff3f5f5b16180d`.
- Backend, Android, unsigned iOS, web, contract, Terraform, filesystem, secret,
  and container-vulnerability checks passed before merge.

## AWS plan, deployment, and drift proof

- The pre-deployment [production plan](https://github.com/baturyusuf/Kelimio/actions/runs/33180534120)
  reported only the expected API task-definition replacement and in-place API
  IAM-policy changes; it contained no durable-data replacement.
- The guarded [production deployment](https://github.com/baturyusuf/Kelimio/actions/runs/33180665679)
  built and scanned all three exact images, applied the task definitions, ran
  Flyway V15/V16 successfully, promoted the migrated API, reached ECS stability,
  and passed the public readiness check.
- The exact deployed images are:
  - API: `sha256:fb309124a2f832786b14d94620c9cecd6b5d70e6df9f541b5429b6e984dd3098`;
  - worker: `sha256:a04cc110f3530edb508464400db043e9d8bea02949c473efc79473362b33c7a4`;
  - scanner: `sha256:457145cc5ee0d510b46b2ee3c7156105e09de8d44b549ec251e1208e5d559172`.
- Those digests, the build revision, and the enabled controlled-teacher flag
  were pinned together in the protected GitHub `production` environment.
- The post-deployment [production plan](https://github.com/baturyusuf/Kelimio/actions/runs/33205322104)
  reported `No changes`.
- A separate post-deployment request returned `{"status":"UP"}` from the HTTPS
  readiness endpoint, and Cognito's issuer discovery document remained reachable.

## Android internal-test artifact

The public prerelease
[Kelimio Priority Beta — 2026-08-28](https://github.com/baturyusuf/Kelimio/releases/tag/internal-apk-2026-08-28-priority-beta)
contains ABI-specific, debug-signed APKs bound at compile time to the production
HTTPS API and Cognito issuer. Splitting by ABI avoids the earlier universal APK's
size.

- ARM64 (recommended, 94,049,322 bytes):
  `sha256:ca6ce00c1d92851d7891cd44d67c234adbd8ae977ebff9fab71717b2a52d54d6`.
- ARMv7 (older 32-bit devices, 73,124,516 bytes):
  `sha256:3174aa63f9444df35c2a52a5d38051d1c06e7a7bbce1579edf990089b4994d8b`.

These artifacts are for owner-operated physical-device testing. They are not
production-signed Google Play artifacts and do not close store-signing,
Play-record, physical-device, authenticated feature-canary, or rollout gates.

## Gates deliberately left open

Google identity still requires the Google OAuth client and secret, SES remains
unapproved for production delivery, Firebase/FCM is absent, final account
anonymization requires an approved retention/legal-hold policy, and offline paid
entitlement expiry/revocation semantics remain unapproved. Public UGC,
moderation, child-safety, legal, commerce, store, recovery, performance, and
operational gates remain open and fail closed where applicable.
