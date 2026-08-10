# Google Play internal-test scripts

Run these scripts from PowerShell 7 on Windows. They resolve the repository root
automatically, so the current directory does not matter.

| Script | Purpose | Local files it creates or changes |
| --- | --- | --- |
| `create-upload-keystore.ps1` | Creates the long-lived Google Play upload key. | `mobile/android/keystores/kelimio-upload.p12`, `mobile/android/keystores/kelimio-upload.pem`, `mobile/android/key.properties` |
| `configure-internal-test.ps1` | Writes the immutable package name and production API/OIDC compile-time values. | `mobile/android/play.properties`, `mobile/config/play.internal.json` |
| `new-internal-version.ps1` | Increments the Flutter/Play build number. | `mobile/pubspec.yaml` |
| `build-internal-aab.ps1` | Runs mobile checks, builds and verifies the signed AAB. | `output/play-internal/*.aab` plus hash/manifest evidence |
| `verify-internal-aab.ps1` | Verifies JAR signing, bundle structure and package identity. | `.cache/bundletool/` and AAB evidence files |
| `configure-cognito-testers.ps1` | Creates the Cognito internal-test group and adds verified testers. | AWS Cognito only |
| `deploy-internal-backend.ps1` | Runs the existing protected production deploy with one API task. | GitHub Actions/AWS only |
| `upload-internal.py` | Uploads later AABs to the existing Play internal track. | Google Play edit/track only |
| `smoke-installed-app.ps1` | Launches the Play-installed package through ADB and checks for a fatal crash. | No persistent project changes |

## Local order

```powershell
pwsh ./scripts/play/create-upload-keystore.ps1

pwsh ./scripts/play/configure-internal-test.ps1 `
  -ApplicationId "com.YOUR_PERMANENT_NAMESPACE.kelimio" `
  -ApiBaseUrl "https://YOUR_API_ENDPOINT" `
  -OidcIssuer "https://cognito-idp.eu-central-1.amazonaws.com/YOUR_POOL_ID" `
  -OidcClientId "YOUR_ANDROID_CLIENT_ID"

pwsh ./scripts/play/new-internal-version.ps1
pwsh ./scripts/play/build-internal-aab.ps1
```

The upload key, real properties files, service-account JSON and generated
internal configuration are intentionally ignored by Git.

The first AAB must be uploaded manually in Play Console. After that, use:

```powershell
python -m pip install -r ./scripts/play/requirements.txt
python ./scripts/play/upload-internal.py `
  --package-name "com.YOUR_PERMANENT_NAMESPACE.kelimio" `
  --aab "./output/play-internal/kelimio-0.1.0+2.aab" `
  --service-account "C:/secure/play-service-account.json"
```
