# Google Play internal testing runbook

## 1. Make the immutable package decision

Before the first Play upload, select the final Android application ID. It must
be a lower-case reverse-domain identifier and cannot be `com.kelimio.app`,
which is only the repository scaffold.

Example only:

```text
com.baturedu.kelimio
```

Do not use the example without accepting it as the permanent package identity.

The current Cognito callback uses the independent custom scheme
`com.kelimio.app:/oauthredirect`. The internal MVP keeps that scheme to avoid
an unnecessary identity-provider migration. Package name and redirect scheme do
not need to be identical.

## 2. Activate the tested backend revision

After this change is merged to `main`, run:

```powershell
pwsh ./scripts/play/deploy-internal-backend.ps1 `
  -Ref main `
  -ConfirmProductionImpact
```

This invokes the existing protected production workflow, runs migrations,
deploys the immutable backend image and activates one ECS API task.

Record the Terraform outputs needed by the mobile build:

```text
runtime.api_endpoint
identity.issuer
identity.android_client_id
identity.user_pool_id
```

## 3. Configure the mobile release

```powershell
pwsh ./scripts/play/configure-internal-test.ps1 `
  -ApplicationId "com.YOUR_PERMANENT_NAMESPACE.kelimio" `
  -ApiBaseUrl "https://THE_API_GATEWAY_ENDPOINT" `
  -OidcIssuer "https://cognito-idp.eu-central-1.amazonaws.com/THE_POOL_ID" `
  -OidcClientId "THE_ANDROID_CLIENT_ID"
```

This creates ignored local files:

```text
mobile/android/play.properties
mobile/config/play.internal.json
```

## 4. Create and protect the upload key

```powershell
pwsh ./scripts/play/create-upload-keystore.ps1
```

Back up these files in an encrypted password manager or offline encrypted
archive:

```text
mobile/android/keystores/kelimio-upload.p12
mobile/android/keystores/kelimio-upload.pem
```

Losing the upload key creates a Play key-reset procedure. Never commit or send
the key through chat or email.

## 5. Build and verify the AAB

Increment the build number for every upload:

```powershell
pwsh ./scripts/play/new-internal-version.ps1
pwsh ./scripts/play/build-internal-aab.ps1
```

The result is written to:

```text
output/play-internal/kelimio-<version>+<build>.aab
```

The build command also produces:

- AAB SHA-256;
- dumped base manifest;
- package-name comparison against `play.properties`;
- strict JAR-signature verification;
- bundletool structural validation.

## 6. Create the Play Console app and make the first upload

1. Create a new Play Console app.
2. Confirm that its package name exactly matches `play.properties`.
3. Accept Play App Signing.
4. Open **Testing > Internal testing**.
5. Create a release and upload the first AAB manually.
6. Add the Turkish listing text from `docs/PLAY_STORE_LISTING_TR.md`.
7. Add testers by email list or Google Group.
8. Save and roll out the internal release.
9. Copy the tester opt-in link.

The first manual upload is required before the Google Play Developer API can
manage later bundles for the app.

## 7. Register the same testers in Cognito

Each tester first registers and verifies email in the app. Then an operator runs:

```powershell
pwsh ./scripts/play/configure-cognito-testers.ps1 `
  -UserPoolId "eu-central-1_XXXXXXXXX" `
  -TesterEmails "tester1@example.com","tester2@example.com"
```

Testers must sign out and sign in again after group assignment. Their new access
token will contain:

```text
cognito:groups = ["kelimio-internal-testers"]
```

Only then does the bounded starter-course installer become authorized by the
production backend.

## 8. Automate later internal releases

Create a Google Cloud service account, enable the Google Play Android Developer
API and grant the service account the minimum app-level Play Console release
permission.

Local upload:

```powershell
python -m pip install -r ./scripts/play/requirements.txt
python ./scripts/play/upload-internal.py `
  --package-name "com.YOUR_PERMANENT_NAMESPACE.kelimio" `
  --aab "./output/play-internal/kelimio-0.1.0+2.aab" `
  --service-account "C:/secure/play-service-account.json" `
  --track internal
```

GitHub Actions build:

```text
Actions > Google Play Internal Build > Run workflow
```

Required Actions variables:

```text
ANDROID_APPLICATION_ID
ANDROID_REDIRECT_SCHEME
KELIMIO_API_BASE_URL
KELIMIO_OIDC_ISSUER
KELIMIO_OIDC_CLIENT_ID
```

Required Actions secrets:

```text
ANDROID_UPLOAD_KEYSTORE_BASE64
ANDROID_UPLOAD_STORE_PASSWORD
ANDROID_UPLOAD_KEY_ALIAS
ANDROID_UPLOAD_KEY_PASSWORD
```

Optional upload secret after the first manual upload:

```text
PLAY_SERVICE_ACCOUNT_JSON
```

## 9. Exit criteria

The internal MVP is accepted only after at least one Play-installed physical
device completes every item in `docs/PLAY_TESTER_CHECKLIST.md` and no P0 data
integrity, authentication, crash or answer-key exposure defect remains.
