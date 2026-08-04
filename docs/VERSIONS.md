# Toolchain and Platform Versions

Baseline accepted: 2026-07-21.

These versions are owner-approved starting pins. Scaffold and CI must enforce them; do not silently float to a new major or a different framework line.

| Component | Pinned baseline | Enforcement artifact when scaffolded | Notes |
| --- | --- | --- | --- |
| Java | 21 LTS | Gradle Java toolchain and CI setup | Production runtime and compilation target. |
| Spring Boot | 3.5.16 | Backend plugin/version catalog | The master requirement is the current stable 3.x line on Java 21. Boot 4 is deliberately not selected. |
| Backend Gradle | 8.14.3 | Committed backend Gradle wrapper | Commit `gradlew`, `gradlew.bat`, wrapper properties, and `gradle-wrapper.jar`. |
| Kotlin | 2.4.10 | Backend plugin/version catalog | Compatibility must be verified by the initial build and CI matrix. |
| Apache POI | 5.5.1 | Backend dependency declaration and Gradle lockfile | Used only by the isolated XLSX import worker/parser boundary; production parsing uses the event/SAX APIs and never evaluates formulas. |
| Apache Commons Compress | 1.28.0 | Backend dependency declaration and Gradle lockfile | Gives preflight and POI one ZIP-name model; `xlsx-v1` additionally rejects all ZIP extras/comments to prevent Unicode-path decoder differentials. |
| AWS SDK for Java v2 | 2.50.2 | Backend BOM, dependency declarations, and Gradle lockfile | Exact pin for S3 multipart presigning/version-bound object access and SQS delivery; upgrade service modules as one BOM-governed set. |
| Flutter | 3.44.0 stable | FVM config and CI setup | One mobile codebase for Android and iOS. |
| Dart | 3.12.x | Bundled with the pinned Flutter SDK; `pubspec` constraint | Flutter 3.44.0 stable currently bundles Dart 3.12.0; do not select Dart independently. |
| Android | target/compile API 36; min SDK 24 | Gradle Android configuration and CI | Raise target API when store policy requires it; lowering min SDK requires an ADR and device/support analysis. |
| Android build | Gradle 8.11.1; Android Gradle Plugin 8.9.1; Kotlin Android 2.1.10 | Flutter-generated Android wrapper and plugin settings | Kept distinct from backend Gradle/Kotlin and compatible with the pinned Flutter scaffold; change only with a native Android build matrix. |
| iOS | deployment target 15.0 | Xcode project/Podfile and CI | A change requires plugin, device reach, and product analysis plus an ADR. |
| Node.js | 24.18.0 LTS | Root `.node-version`, package engines, and CI | Used by Next.js applications and contract tooling. |
| Next.js | stable 16.2.x line | Web `package.json` and committed lockfile | Pin the exact stable 16.2 patch selected during scaffold; no floating caret for the framework baseline. |
| Terraform | 1.15.8 | `required_version`, CI setup, and lockfile | Commit `.terraform.lock.hcl`; never commit state or secret-bearing tfvars. |
| Terraform providers | AWS 6.57.1; Archive 2.8.0; Random 3.9.0 | Committed production `.terraform.lock.hcl` | Random passwords/bytes use Terraform ephemeral values and AWS write-only secret arguments so generated values are not retained in state. |

## Reproducibility policy

- Application lockfiles and build wrappers are source artifacts and must be committed.
- CI verifies the active tool versions before building.
- Dependency bots may propose upgrades but may not bypass test, compatibility, security, or rollout gates.
- Generated OpenAPI clients are reproducible from a versioned contract; generation drift fails CI.
- Environment images and actions use immutable releases or digests where practical.

## Spring Boot 3 versus Boot 4

The upstream ecosystem may advertise Spring Boot 4 as current, but the governing master requirement explicitly selects a stable Spring Boot 3.x backend on Java 21. The baseline is therefore Spring Boot 3.5.16. A Boot 4 migration requires a superseding ADR covering Java/toolchain requirements, Spring Security and observability changes, library/plugin support, migration scope, benchmark results, rollback, and store/backend release compatibility.

## Upgrade procedure

1. Open an upgrade change with release notes and compatibility/security motivation.
2. Update the enforcement artifact and lockfile together.
3. Run the complete affected unit, architecture, integration, generated-client, mobile/web build, migration, and smoke suites.
4. Record a new ADR for a major version, platform minimum, runtime model, or compatibility boundary change.
5. Roll through development, staging, and production using the documented staged-release and rollback plan.

The current enforcement artifacts are present for the backend, Android, Flutter/Dart, Node workspaces, generated clients, and Terraform: modern Gradle wrappers, dependency locks, exact constraints, and exact CI setup pins. The iOS deployment minimum is configured, but `mobile/ios/Podfile.lock` must still be generated and verified on the macOS build path before the native dependency graph is reproducible. Any new workspace must adopt the same enforcement policy before it can be treated as reproducible.
