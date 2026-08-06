# Google Play MVP file map

## Files changed in the application

| Repository path | Action | Purpose |
| --- | --- | --- |
| `.gitignore` | Replace | Excludes real signing, Play and service-account configuration. |
| `mobile/android/app/build.gradle.kts` | Replace | Reads the permanent package name, configures release upload-key signing and blocks scaffold/unsigned Play bundles. |
| `mobile/lib/core/config/app_config.dart` | Replace | Adds bounded `KELIMIO_INTERNAL_TEST_MODE`. |
| `mobile/lib/application/catalog_controller.dart` | Replace | Permits starter installation in local or internal-test mode. |
| `mobile/lib/presentation/screens/catalog_screen.dart` | Replace | Shows the starter installer in the internal-test build. |
| `mobile/test/core/app_config_test.dart` | Replace | Tests the internal-test gate. |
| `backend/src/main/kotlin/com/kelimio/api/development/InternalTesterPolicy.kt` | Add | Authorizes production starter installation only for a Cognito group. |
| `backend/src/main/kotlin/com/kelimio/api/development/LocalStarterCourseController.kt` | Replace | Reads the authenticated Cognito group claim. |
| `backend/src/main/kotlin/com/kelimio/api/development/LocalStarterCourseService.kt` | Replace | Keeps local flag behavior and accepts the bounded production group authorization. |
| `backend/src/test/kotlin/com/kelimio/api/development/InternalTesterPolicyTest.kt` | Add | Verifies fail-closed group behavior. |
| `.github/workflows/play-internal-build.yml` | Add | Builds, verifies, retains and optionally uploads the signed internal AAB. |

## Templates to copy locally

| Template | Copy to | Required edits |
| --- | --- | --- |
| `mobile/android/key.properties.example` | `mobile/android/key.properties` | Store/key passwords and key path. Prefer the keystore script instead of editing manually. |
| `mobile/android/play.properties.example` | `mobile/android/play.properties` | Permanent `applicationId`; normally keep current redirect scheme. |
| `mobile/config/play.internal.example.json` | `mobile/config/play.internal.json` | Production API endpoint, Cognito issuer/client and redirect values. |

## Scripts

All scripts are already located under `scripts/play/`; do not move them.

| Script | Input or configuration you supply |
| --- | --- |
| `create-upload-keystore.ps1` | Password and optional certificate subject. |
| `configure-internal-test.ps1` | Permanent package ID, API URL, OIDC issuer and client ID. |
| `new-internal-version.ps1` | Optional version name/build number; otherwise increments build. |
| `build-internal-aab.ps1` | Reads the generated ignored files. |
| `verify-internal-aab.ps1` | AAB path; optionally a predownloaded bundletool JAR. |
| `configure-cognito-testers.ps1` | Cognito user pool ID and verified tester emails. |
| `deploy-internal-backend.ps1` | Merged Git ref and explicit production-impact switch. |
| `upload-internal.py` | Existing Play app/package, AAB and service-account JSON. |
| `smoke-installed-app.ps1` | Permanent package ID and optional ADB device ID. |
