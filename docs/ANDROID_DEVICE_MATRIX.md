# Android Device Matrix

This matrix is local engineering evidence for the Flutter Android client. It
does not close the production device, accessibility, performance, native OIDC,
Google Play, or signed-artifact gates in `docs/LAUNCH_BLOCKERS.md` and
`docs/RELEASE_CHECKLIST.md`.

## Repository-managed profiles

| Profile key | AVD | Runtime | Device profile | Purpose |
| --- | --- | --- | --- | --- |
| `api24-min` | `kelimio_api24_min` | Android 7.0 / API 24, Google APIs x86_64 | Nexus 5 | Exercise the declared minimum SDK and older Android storage/runtime behavior. |
| `api30-mid` | `kelimio_api30_mid` | Android 11 / API 30, Google APIs x86_64 | Pixel 3a | Exercise an intermediate Android generation and a mid-size phone layout. |
| `api36-current` | `kelimio_api36` | Android 16 / API 36, Google APIs x86_64 | Pixel 7 | Exercise the compile/target API and current development runtime. |

All three images intentionally omit the Play Store. Google Play Console access
is not required to create them or run this matrix. Billing, Play Integrity,
store signing, and store delivery require separate later evidence.

The profiles are an allowlist. `scripts/android-emulator.ps1` refuses arbitrary
AVD names and refuses to modify an existing allowlisted AVD when its system
image or hardware profile does not match the repository definition. The
compile toolchain remains API 36 even when the application runs on API 24 or
API 30.

## Automated checks

Run the sequential smoke matrix from the repository root:

```powershell
.\scripts\android-device-matrix.cmd -Headless
```

Each profile cold-boots and runs these existing integration tests with the
isolated `com.kelimio.app.smoke` flavor:

1. `integration_test/startup_smoke_test.dart`: a signed-out cold start reaches
   the sign-in screen;
2. `integration_test/secure_storage_smoke_test.dart`: Android secure storage
   writes, reads, and deletes a value;
3. `integration_test/auth_restore_smoke_test.dart`: the AppAuth adapter restores
   an empty session, Drift opens and clears, and the authentication controller
   restores signed-out state.

That is five checks per profile and fifteen checks for the matrix. These smoke
checks need neither Google Play nor the Docker service stack. They use the
test-only application ID and never read or clear `com.kelimio.app` data.

The existing real Keycloak/Mailpit/PostgreSQL registration-to-progress journey
can additionally run at the minimum and current API endpoints:

```powershell
.\scripts\android-device-matrix.cmd -Headless -IncludeEndpointE2e
```

The endpoint option deliberately omits the middle API because the two boundary
runs exercise runtime compatibility while avoiding a third expensive fresh
Docker environment. It does not exercise the native FlutterAppAuth Custom Tab
or redirect handoff; the real protocol session is injected at the mobile auth
interfaces as documented in `mobile/README.md`.

Each repository-managed emulator receives loopback reverse mappings for
LocalStack (`4566`), the API (`8080`), and Keycloak (`8081`). Consequently,
owner-scoped presigned upload URLs using the local-only `localhost` endpoint
remain reachable without accepting emulator-specific hosts in backend
configuration.

## State and resource safety

The runner is serial and holds a machine-wide Kelimio matrix mutex. Before it
changes emulator state, it records every running repository AVD, its reverse
port mappings, and whether the normal application is installed. It refuses to
continue while a non-Kelimio emulator is running. During cleanup it removes
only the isolated smoke package, stops only the three allowlisted AVDs, restores
the originally running repository AVDs and their mappings, and verifies that
the normal application installation state did not change. It never deletes an
AVD, wipes an AVD data partition, or touches the normal application package.

Run the matrix sequentially. Emulator profiles approximate Android version,
screen geometry, and platform behavior; software-rendered emulators do not
measure real low- or mid-tier device CPU, GPU, thermal, battery, jank, startup,
or crash-free performance. Real-device performance, TalkBack/manual
accessibility, app update/migration, background/restore, deep-link UI, billing,
ads, push, and integrity coverage remain open release work.
