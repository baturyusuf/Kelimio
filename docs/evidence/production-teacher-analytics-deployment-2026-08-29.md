# Production teacher-analytics deployment evidence — 2026-08-29

## Scope and boundaries

This record covers the guarded deployment of ADR-023's owner-scoped,
active-release teacher analytics to AWS account `923300948109` in
`eu-central-1`. The analytics endpoint is part of the controlled teacher API;
the existing production teacher-import feature remained enabled during the
deployment. This is not evidence of public author onboarding or store-release
readiness.

## Immutable source and review

- Reviewed pull request: [#73](https://github.com/baturyusuf/Kelimio/pull/73).
- Deployed merge revision: `429fb86e4d46173fb1e80084c9ce220fa373f610`.
- Backend, Android, unsigned iOS, web, contract, filesystem, secret, and
  container-vulnerability checks passed before merge.
- The full backend suite passed 212/212 tests, Flutter passed 150/150 tests,
  and the generated Dart client passed 565/565 tests.

## AWS deployment proof

- The guarded [production deployment](https://github.com/baturyusuf/Kelimio/actions/runs/33261350549)
  completed successfully in 11m03s.
- The workflow built and pushed immutable API, worker, and scanner images,
  passed Trivy and ECR critical-vulnerability gates for every exact image, and
  retained the API CycloneDX SBOM.
- Exact image digests applied to the task definitions:
  - API: `sha256:99c8305806965b0e8be6c96972c9719451f01c24854cb4ed4297e9a71008e03f`;
  - worker: `sha256:529ec7d07c584ac48c294fee60b8bbce91793e7a7133826f852e439de43c3beb`;
  - scanner: `sha256:deb8e005e013cd11dce4c61bb40f1f5a23daa0e22cef62ec46f16c590fcf6138`.
- The one-shot migration task exited successfully before API promotion. This
  slice adds no schema migration; the task verified the deployed application
  against the existing migration state.
- ECS promotion reached stability and the workflow readiness gate passed.
- A separate request after the workflow returned `{"status":"UP"}` from
  `https://xz5qt0pqoa.execute-api.eu-central-1.amazonaws.com/actuator/health/readiness`.

## Privacy and failure boundaries retained

- The course-editor module verifies teacher authorization and immutable course
  ownership, then calls the progress module through its application interface;
  it does not read progress tables directly.
- Results are bound to the active immutable release. Unresolved or dead
  learning/reprojection work returns an updating state instead of partial
  aggregates.
- Learner activity count may be shown, but completion and answer-performance
  totals are withheld until at least three learners are present.
- The contract exposes no learner identifier, name, email, answer text, option,
  matching relationship, or per-learner row.

## Internal Android artifact

The public prerelease
[Kelimio AWS Analytics Internal Beta](https://github.com/baturyusuf/Kelimio/releases/tag/internal-apk-2026-08-29-analytics-beta)
contains production-connected, ABI-specific internal-test APKs built from the
same deployed revision.

- ARM64, recommended for modern devices (34,687,215 bytes):
  `sha256:3511cfebf47c11f8ed25321ff6973e655141912b745b2c8aef8b268fa4a04992`.
- ARMv7, for older 32-bit devices (32,507,833 bytes):
  `sha256:787e254d12224e86604492f0edd4a0ef7f93ddcae5c7de0d915b134b49fbd71c`.

Android Signature Scheme v2 verification passed with the local debug
certificate. These APKs are not Play-signed artifacts.

## Gates deliberately left open

Google identity remains unconfigured, SES has no approved production sender,
and Firebase/FCM is absent. Real production workbook/malware/archive/DLQ and
natural scale-down canaries, supported physical-device analytics and editor
conflict tests, public UGC/moderation, child-safety, legal, commerce, store,
recovery, performance, and operational acceptance remain open and fail closed
where applicable.
