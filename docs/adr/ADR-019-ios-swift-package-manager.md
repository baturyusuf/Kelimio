# ADR-019: iOS Native Dependencies Use Swift Package Manager

- Status: Accepted
- Date: 2026-08-04
- Decision owners: Product owner and architecture
- Clarifies: repository lockfile guidance and the iOS baseline in
  `docs/VERSIONS.md`

## Context

The pinned Flutter 3.44 toolchain enables Swift Package Manager (SwiftPM) by
default for iOS and macOS plugins. The generated iOS project has already been
migrated: `FlutterGeneratedPluginSwiftPackage` is a local package dependency of
the Runner target and the shared Runner scheme runs Flutter's prepare step.

The repository also retained a pre-migration `ios/Podfile`. On the clean macOS
CI build, Flutter identified that every iOS plugin supports SwiftPM but still
attempted CocoaPods integration because the stale Podfile existed. Xcode then
failed because there was intentionally no Pods workspace or Podfile.lock.

The general repository guidance says to commit `Podfile.lock`. Applying that
instruction to a project that no longer uses CocoaPods would reintroduce two
native dependency managers and contradict the pinned Flutter baseline. This
conflict must be resolved explicitly rather than by generating a redundant
lockfile.

## Decision

- Kelimio's iOS target uses Flutter 3.44's default SwiftPM integration.
- Remove the stale `mobile/ios/Podfile`; do not generate Pods or a
  `Podfile.lock` while every selected plugin supports SwiftPM.
- Keep the checked-in Xcode project and shared scheme as the authoritative
  SwiftPM integration artifacts. Commit both Xcode-generated
  `Package.resolved` files so AppAuth-iOS's exact version and revision are
  reproducible. Dart packages remain pinned by `mobile/pubspec.lock`.
- The macOS CI build is the reproducibility gate. It must run
  `flutter pub get --enforce-lockfile`, complete an unsigned iOS build, reject
  generated dependency-resolution drift, and retain the resolution files as
  short-lived build evidence.
- If a future required plugin lacks SwiftPM support, adding a CocoaPods fallback
  requires a superseding ADR, a committed Podfile and Podfile.lock, and a clean
  macOS compatibility build. CocoaPods must not be reintroduced silently.

## Consequences

- The current native dependency graph has one manager and follows Flutter's
  supported default instead of maintenance-mode CocoaPods.
- The repository-wide instruction to commit `Podfile.lock` is non-applicable
  while no Podfile or CocoaPods integration exists; it remains mandatory if a
  future accepted change restores CocoaPods.
- This decision does not create an iOS release target or relax Android/Google
  Play gates. It only keeps the shared Flutter project continuously buildable.
