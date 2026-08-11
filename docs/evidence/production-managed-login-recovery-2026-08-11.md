# Production Managed Login recovery evidence — 2026-08-11

## Incident

The Android production build reached the configured Amazon Cognito authorization
endpoint, but Cognito returned `403` with `Login pages unavailable. Please
contact an administrator.` The API readiness endpoint remained healthy during
the incident.

The production domain was already configured for Managed Login version 2. AWS
requires a branding style for each app client that uses this experience. The
Android app client had no `aws_cognito_managed_login_branding` resource, so its
login pages were nonfunctional.

## Correction

- PR #40 declared an Android-client Managed Login branding resource using the
  Cognito-provided default values and added regression coverage.
- Initial production deploy run
  [31465438800](https://github.com/baturyusuf/Kelimio/actions/runs/31465438800)
  failed closed before migration or promotion because the protected deploy role
  lacked `cognito-idp:CreateManagedLoginBranding`.
- PR #41 added create, update, and delete Managed Login branding actions to the
  bootstrap-owned production deploy policy, plus a bootstrap policy test.
- The protected, exact-account reconciliation run
  [31466229098](https://github.com/baturyusuf/Kelimio/actions/runs/31466229098)
  updated the already-applied inline policy, verified the three actions, and
  deleted its per-run temporary helper role on exit. The one-time reconciliation
  workflow was then removed from the repository.
- Production deploy run
  [31466271010](https://github.com/baturyusuf/Kelimio/actions/runs/31466271010)
  passed account and region guards, immutable ARM64 image build, Trivy and ECR
  vulnerability gates, SBOM retention, Terraform apply, the one-shot Flyway V13
  migration check, ECS promotion, and public database-aware readiness.

## Live verification

After the successful deploy:

- `GET https://xz5qt0pqoa.execute-api.eu-central-1.amazonaws.com/actuator/health/readiness`
  returned HTTP `200`.
- A real authorization-code-with-PKCE request for client
  `fjbtkqm379amqc28d8frtprdd` and registered redirect URI
  `com.kelimio.app:/oauthredirect` returned HTTP `200` at `/login`.
- The rendered page title was `Sign-in` and the visible DOM contained the email
  and password inputs, the `Sign in` button, password recovery, and account
  creation link. The former unavailable-page error was not rendered.

No user credentials were entered and no account was created during this
verification. A physical-device sign-in remains the owner acceptance step; the
server-side endpoint and redirect configuration used by the existing APK did
not change, so rebuilding the APK is not required for this correction.
