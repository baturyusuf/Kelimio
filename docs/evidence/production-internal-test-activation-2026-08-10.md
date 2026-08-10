# Production internal-test activation evidence — 2026-08-10

## Scope

This record covers the guarded activation of the ADR-018 production API for a
controlled Android internal test. It does not assert public-launch readiness,
Google Play release signing, a completed native auth-to-answer canary, or closure
of any launch blocker.

## Immutable release

- Source revision: `ba9caa65b768c9c2fa10d70dcd5deba4d7672028`
  (`Prepare Google Play internal-test MVP (#38)`).
- ECR image digest:
  `sha256:9791cdf23a2bda4656275dce651730d4e6481f36b97957764faf553cb694d878`.
- [Production deployment run 31405817164](https://github.com/baturyusuf/Kelimio/actions/runs/31405817164)
  passed the account/region guard, Terraform foundation check, ARM64 image build,
  exact-image Trivy high/critical gate, CycloneDX SBOM retention, ECR critical
  scan, task-definition apply, one-shot Flyway V14 migration, immutable task
  promotion, ECS stabilization, and database-aware readiness check.
- The protected `production` environment pins the deployed image digest and its
  producing source revision together.
- [Post-activation plan run 31406929936](https://github.com/baturyusuf/Kelimio/actions/runs/31406929936)
  reported `No changes. Your infrastructure matches the configuration.`

## Live connectivity checks

- `GET https://xz5qt0pqoa.execute-api.eu-central-1.amazonaws.com/actuator/health/readiness`
  returned `{"status":"UP"}` after promotion.
- Cognito discovery returned the expected issuer for user pool
  `eu-central-1_jO9MokKQO`.
- The public Android OAuth client `fjbtkqm379amqc28d8frtprdd` accepted an
  Authorization Code + PKCE request for
  `com.kelimio.app:/oauthredirect` and redirected to the Cognito hosted login.
- No credential, authorization code, access token, refresh token, email address,
  or secret value was recorded by these checks.

## Android sideload artifact

An Android production-flavor debug APK was compiled with the live HTTPS API,
Cognito issuer/client, registered redirect and post-logout URIs, internal-test
mode enabled, and local-development tools disabled.

- File: `kelimio-aws-internal-debug.apk`
- Package: `com.kelimio.app`
- Version: `0.1.0` (`versionCode` 1)
- Minimum/target SDK: 24/36
- Size: 206,596,826 bytes
- SHA-256:
  `C54827DD7373A69D8444460848D1C368EE212ADBEDE95B23E6C58C907AB3600A`
- Signature verification: APK Signature Scheme v2 passed with the local Android
  debug certificate.

This debug-signed artifact is suitable only for direct installation on a
controlled test device. It is not the upload-key-signed AAB required for Google
Play. A tester must register and verify an email, be assigned to the
`kelimio-internal-testers` Cognito group, then sign out and in again before the
bounded starter-course flow is authorized.

## Gates that remain open

- Native phone registration, verification, deep-link return, profile setup,
  starter-course installation, enrollment, Type-A/B/C/D answer submission,
  authoritative score/energy, idempotent retry, projection, and mobile display
  still require the controlled device canary.
- Google identity remains disabled until its OAuth secret and account-linking
  evidence exist. Cognito's default email sender is only the bounded internal
  registration path; an approved production sender/domain remains open.
- Permanent Google Play application ID, upload key, first manual AAB upload,
  store metadata, tester list, and all public release gates remain open.
