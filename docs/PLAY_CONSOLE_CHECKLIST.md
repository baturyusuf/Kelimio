# Play Console internal-test checklist

## App identity and signing

- [ ] Permanent `applicationId` is approved and differs from `com.kelimio.app`.
- [ ] A Play Console app exists with the exact package identity.
- [ ] Play App Signing is enabled.
- [ ] The upload certificate SHA-256 is recorded outside source control.
- [ ] The upload keystore has an encrypted backup and a named custodian.
- [ ] Every uploaded `versionCode` is greater than all previous uploads.

## Internal track

- [ ] The first AAB was uploaded manually.
- [ ] The internal track release status is available to testers.
- [ ] The tester email list or Google Group is configured.
- [ ] The opt-in URL opens for every tester account.
- [ ] Release notes clearly say this is an internal MVP.
- [ ] No closed, open or production rollout has been started.

## Store-facing content

- [ ] App name and descriptions use `docs/PLAY_STORE_LISTING_TR.md`.
- [ ] A non-default high-resolution store icon is uploaded before wider testing.
- [ ] Screenshots reflect the current build, not design mockups.
- [ ] Support contact is monitored.
- [ ] Privacy-policy URL is added before any track beyond internal testing.
- [ ] Content rating and target-audience answers do not claim completed child
      safety controls that are not yet implemented.

## Runtime

- [ ] Production API readiness returns `UP`.
- [ ] Cognito email registration and verification succeed.
- [ ] Tester is assigned to `kelimio-internal-testers`.
- [ ] Tester signs in again after group assignment.
- [ ] Starter course installation is visible only in the internal build.
- [ ] Normal production build with `KELIMIO_INTERNAL_TEST_MODE=false` hides it.

## Release evidence

- [ ] Signed AAB is retained with SHA-256 and manifest evidence.
- [ ] Git SHA and backend deployment run are recorded.
- [ ] Physical-device make/model, Android version and Play-installed version are recorded.
- [ ] `docs/PLAY_TESTER_CHECKLIST.md` is completed.
- [ ] P0 defects block the next internal release.
