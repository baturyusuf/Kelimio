# Kelimio mobile

Production Flutter client for the online learning vertical slice. It targets
Flutter 3.44 / bundled Dart 3.12 and contains no demo repositories or fallback data.

Required compile-time configuration:

```text
--dart-define=KELIMIO_API_BASE_URL=https://api.example.com
--dart-define=KELIMIO_OIDC_ISSUER=https://identity.example.com
--dart-define=KELIMIO_OIDC_CLIENT_ID=kelimio-mobile
```

Optional configuration:

```text
--dart-define=KELIMIO_OIDC_REDIRECT_URI=com.kelimio.app:/oauthredirect
--dart-define=KELIMIO_OIDC_POST_LOGOUT_REDIRECT_URI=com.kelimio.app:/logout
--dart-define=KELIMIO_LOCAL_DEVELOPMENT_TOOLS=true
```

`KELIMIO_LOCAL_DEVELOPMENT_TOOLS` is accepted only by non-production builds.
It reveals an explicit local-only action that installs the reviewed mixed
Type-A/Type-B/Type-C/Type-D starter release v4 through the local backend; it
contains eight questions (five A, one B, one C, and the four-pair `EV` Type-D
question), never creates users or learning results, and is rejected outside
enabled local mode.

After a valid OIDC session, the app loads `/v1/me`. Provisional users must
complete the one-time app-language, target-language, support-language, and time-
zone setup before any product API is available. This setup is not legal consent.
The backend is the gate authority; mobile routing only mirrors its state. A
saved support language becomes the enrollment default when the course supports
it.

Missing or unsafe production values render an explicit configuration error;
they never select a fake backend. Generate localizations, format, analyze, and
test with:

```text
flutter pub get --enforce-lockfile
flutter gen-l10n
dart format --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
```

For the repository-managed Android emulator, start the local services and then
run from the repository root:

```powershell
.\scripts\android-emulator.cmd -Action start
cd mobile
flutter run -d emulator-5554 `
  --flavor production `
  --dart-define=KELIMIO_API_BASE_URL=http://localhost:8080 `
  --dart-define=KELIMIO_OIDC_ISSUER=http://localhost:8081/realms/kelimio `
  --dart-define=KELIMIO_OIDC_CLIENT_ID=kelimio-mobile `
  --dart-define=KELIMIO_LOCAL_DEVELOPMENT_TOOLS=true

flutter test integration_test -d emulator-5554 `
  --flavor smoke `
  --dart-define=KELIMIO_API_BASE_URL=http://localhost:8080 `
  --dart-define=KELIMIO_OIDC_ISSUER=http://localhost:8081/realms/kelimio `
  --dart-define=KELIMIO_OIDC_CLIENT_ID=kelimio-mobile `
  --dart-define=KELIMIO_OIDC_REDIRECT_URI=com.kelimio.app.smoke:/oauthredirect `
  --dart-define=KELIMIO_OIDC_POST_LOGOUT_REDIRECT_URI=com.kelimio.app.smoke:/logout `
  --dart-define=KELIMIO_ISOLATED_DEVICE_TEST_STORAGE=true `
  --dart-define=KELIMIO_LOCAL_DEVELOPMENT_TOOLS=true
```

The script configures ADB reverse mappings for the API and Keycloak ports. The
AVD contains Google APIs but intentionally has no Play Store; store billing and
Play Integrity remain separate release-stage tests.

From the repository root, `scripts\local-android-e2e.cmd` runs the isolated
real-registration acceptance flow. It uses a fresh Flyway V8 database, a
per-run random 32-byte matching-replay key, separate Compose volumes and ports,
public Keycloak registration, Mailpit verification, a genuine S256 PKCE token,
the generated API repositories, real Drift storage, and the production Flutter
UI. It verifies profile gating, starter-course installation, enrollment, all
eight server-scored answers, Type-B replay, Type-C replay/reconciliation,
Type-D matching, reordered same-map replay and owner-scoped reconciliation, the
final 8/8 and 480/480 projection at version 9, sign-out, and private-cache
removal. It also proves that changing a submitted matching edge returns `409`
without mutation, isolated cleanup leaves no project resources or test images,
and the normal Compose services and ADB mappings remain unchanged. It is skipped by ordinary
integration-test invocations unless the guarded runner enables it.

Type-C entry sends the word or phrase only as learner-answer content, alongside
the required submission/question identifiers, and never grades it locally. Raw
or canonical typed text is not written to Drift recovery,
logs, analytics, or diagnostic string output. If the backend rejects a Type-C
body with `413` or `422`, the app returns to a blank input using the same reserved
submission ID; this permits safe correction without retaining the rejected text
or weakening idempotency. After an ambiguous network failure or restart, the app
uses the ownership-scoped recorded-answer endpoint to reconcile a committed
result before allowing a new submission.

Type-D uses an accessible two-stage path: select one target item, then one
support item. The two sides arrive as independent ordered arrays, and the client
submits only after it holds one complete bijection. It never grades a tentative
pair locally; the entire question is correct only after authoritative feedback.
The attempt's pinned support language controls the support labels across retry,
replay, and reconciliation. Submitted and correct mappings remain in live
memory only and are excluded from Drift recovery and diagnostic strings. A
recoverable process restart keeps only the normal submission identity/state;
the board is rebuilt empty unless reconciliation returns the no-store committed
correct mapping.

Flutter analysis is clean and the full suite passes 117/117 tests, including
the focused 18/18 Type-D domain/controller/widget/accessibility coverage. The
guarded eight-question Android E2E also passes against fresh Flyway V8 services
with zero isolated resources or images left after cleanup.

Android has explicit `production`, `smoke`, and `e2e` flavors. Normal Android
run/build commands select `production`; ordinary device tests select `smoke`,
whose `com.kelimio.app.smoke` package may reset only its own storage; and the
guarded acceptance runner alone selects `e2e`. The iOS project has no
flavor/scheme change and therefore remains buildable with its existing `Runner`
scheme.

The test overrides only the authentication repository and access-token
interface after the real protocol exchange. It intentionally does not claim
that the native Custom Tab, app-link callback, or secure-token persistence path
has been exercised; retain those checks for native/staging acceptance.

Release signing credentials are intentionally absent from source control. The
deployment pipeline must supply the Android upload key and iOS signing profile;
release artifacts are never signed with development credentials.

`com.kelimio.app` is a non-published scaffold identifier shared with the local
OIDC redirect configuration. It is not owner approval for a store identity.
Android application ID, iOS bundle ID, universal-link domains, and redirect
schemes must be replaced together after the owner closes the corresponding
decision in `docs/OWNER_ACTIONS.md`; no artifact using the scaffold identifier
may enter a store track.

The domain layer is pure Dart. OIDC, Dio, Drift/SQLite, secure storage, Riverpod,
and Flutter UI are kept in adapters/application/presentation layers.
