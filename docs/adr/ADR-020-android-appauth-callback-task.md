# ADR-020: Android AppAuth Callback Task Ownership

- Status: Accepted
- Date: 2026-08-24

## Context

The Android launcher activity deliberately had an empty task affinity while
AppAuth's authorization and redirect activities used a different affinity.
On Android 16 with Chrome Custom Tabs, Cognito returned the custom-scheme
callback to a new task. `RedirectUriReceiverActivity` then created a second
`AuthorizationManagementActivity`, which logged `No stored state - unable to
handle response`. The original PKCE request remained in the first activity,
and `flutter_appauth` surfaced the failed handoff as a user cancellation.

Giving only the two AppAuth activities an empty or shared affinity did not
solve the problem because the initial activity-result launch still placed the
authorization manager in the launcher's task. The external callback then
created a different task.

## Decision

- `MainActivity`, `AuthorizationManagementActivity`, and
  `RedirectUriReceiverActivity` share the application-scoped
  `${applicationId}.auth` task affinity.
- `MainActivity` uses `singleTask`, so one application task owns the pending
  authorization result.
- The two AppAuth activities are excluded from recents.
- The callback remains Authorization Code + S256 PKCE. The task affinity is
  navigation configuration, not an authorization boundary; state, nonce, and
  PKCE validation remain mandatory.
- Only the redirect receiver remains exported as required by the custom URI
  callback. The authorization management activity remains non-exported in the
  merged manifest.

## Consequences

- Cognito callbacks are delivered to the `AuthorizationManagementActivity`
  instance that owns the pending request instead of a state-less duplicate.
- The app returns from Chrome rather than leaving the hosted page spinning and
  later reporting cancellation.
- A manifest regression test pins the shared affinity and single-task owner.
- The custom URI scheme can still be claimed by another installed application;
  PKCE prevents that application from redeeming a stolen code, but supported
  physical-device callback evidence remains a release gate. A verified HTTPS
  App Link may supersede the custom scheme in a later ADR.

## Evidence

On the API 36 Android emulator, the previous task layout reproduced the
state-less callback. With this decision applied, a callback carrying the live
request state returned to the original task, did not emit `No stored state`,
passed state validation, and advanced to the token exchange. A deliberately
fake authorization code then failed at the expected protocol boundary and was
reported as a generic authentication error rather than a cancellation.
