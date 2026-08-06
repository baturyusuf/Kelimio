# Kelimio Google Play internal-test MVP

## Release definition

This milestone is an **internal testing MVP**, not a public production launch.
It deliberately uses the existing server-authoritative learning vertical slice
and excludes features that are not required to test the core learning value.

## Included, release-blocking flow

A tester must be able to:

1. install the app from the Google Play internal-test opt-in link;
2. register or sign in through the production Cognito hosted flow;
3. verify email and complete first-login language/time-zone setup;
4. install the bounded starter course when their access token contains the
   `kelimio-internal-testers` Cognito group;
5. view the course, enroll and open its test;
6. answer the existing Type A, Type B, Type C and Type D questions;
7. receive backend-authoritative correctness, score, energy and progress;
8. retry safely without duplicate score/energy mutation;
9. sign out and sign back in without exposing another user's private state.

## Included technical controls

- immutable Google Play `applicationId` supplied outside source control;
- release upload-key signing with no debug-key fallback;
- HTTPS-only production API and OIDC compile-time values;
- internal-test UI flag that exposes only starter-course installation;
- production starter-course authorization by Cognito group, not by an embedded
  client secret or public feature flag;
- signed AAB, bundletool validation, manifest/package verification and SHA-256;
- repeatable version-code increment;
- local and GitHub Actions internal-build paths;
- optional Google Play Developer API upload after the first manual bundle;
- tester and Play Console checklists.

## Explicitly excluded from this MVP

- teacher Excel import and mobile authoring in production;
- paid courses, Google Play Billing, App Store purchases or entitlements;
- rewarded ads;
- teacher earnings, KYC/KYB, tax or payouts;
- public profiles, leaderboards and social discovery;
- offline scored learning;
- production admin/moderation console;
- public/open/production Play tracks;
- iOS/TestFlight;
- public launch claims, full legal acceptance or final penetration/load evidence.

The excluded areas remain release blockers for a public launch, but they do not
prevent a controlled internal test of the learning loop.
