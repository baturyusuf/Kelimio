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
It reveals an explicit empty-catalog action that installs the reviewed Type-A
starter course through the local backend; it never creates users or learning
results, and the backend rejects the command outside its enabled local mode.

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
  --dart-define=KELIMIO_API_BASE_URL=http://localhost:8080 `
  --dart-define=KELIMIO_OIDC_ISSUER=http://localhost:8081/realms/kelimio `
  --dart-define=KELIMIO_OIDC_CLIENT_ID=kelimio-mobile `
  --dart-define=KELIMIO_LOCAL_DEVELOPMENT_TOOLS=true

flutter test integration_test -d emulator-5554 `
  --dart-define=KELIMIO_API_BASE_URL=http://localhost:8080 `
  --dart-define=KELIMIO_OIDC_ISSUER=http://localhost:8081/realms/kelimio `
  --dart-define=KELIMIO_OIDC_CLIENT_ID=kelimio-mobile `
  --dart-define=KELIMIO_LOCAL_DEVELOPMENT_TOOLS=true
```

The script configures ADB reverse mappings for the API and Keycloak ports. The
AVD contains Google APIs but intentionally has no Play Store; store billing and
Play Integrity remain separate release-stage tests.

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
