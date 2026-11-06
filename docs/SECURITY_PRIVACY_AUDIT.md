# ASCEND security and privacy audit

**Status:** **PARTIAL SOURCE REVIEW — RUNTIME AUDIT BLOCKED.** This document separates source design from verified behavior. It is not a security certification or legal opinion.

## Data-flow inventory (source-level)

| Data / operation | Intended location or recipient | Source evidence | Verification status |
|---|---|---|---|
| Camera preview and temporary JPEG | Android app-private CameraX cache (`CAP*.jpg`) | `ScanScreen`, CameraX package source inspection, cache-cleanup helper | Device path and lifecycle not tested; startup cleanup is best effort. |
| Face detector / normalized landmarks | Android MediaPipe Tasks, then in-process Flutter value | `MainActivity.kt`, `face_analysis_engine.dart` | Runtime/model compatibility not tested. |
| Accepted capture photo | App-private file encrypted with AES-GCM | `PrivatePhotoStore` / `SecureVault` | Pure Dart test source exists but is unrun; Keystore/filesystem not device-tested. |
| User preferences, plan, scan geometry, check-ins, subscription snapshot | SQLite payloads encrypted with AES-GCM; relational IDs/indexes remain database metadata | `LocalRepository`, `LocalDatabase`, `SecureVault` | No database/device inspection or recovery test. |
| Purchase and entitlement | Google Play / RevenueCat only when configured; SDK may use an anonymous App User ID | `SubscriptionService`, paywall and legal draft | Not configured or sandbox-tested; final request contents/destinations unverified. |
| Local notifications | Android notification subsystem; no photo/landmark fields in notification body | `ReminderService`, manifest | Not device-tested. |
| Subscription management link | External Google Play subscription settings URL containing application package name | Native `ascend/store` handler | Intent behavior not device-tested. |

## Permissions and network

Source `AndroidManifest.xml` declares `CAMERA`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE`, and `INTERNET`. CameraX manifest additions for `RECORD_AUDIO`, `WRITE_EXTERNAL_STORAGE`, and required generic camera hardware are marked for removal with manifest-merger tools directives. **The merged release manifest has not been built or inspected**, so the actual permission set is unknown. `INTERNET` is needed for configured billing; it is not a network allowlist.

Source search found no app-owned HTTP client/image-upload endpoint. That fact is not proof of no transmission: transitive/native SDKs can send data independently. Inspect actual traffic in the final release artifact while exercising onboarding, scan, coaching, progress, purchase, restore and offline flows.

## MediaPipe telemetry finding

The inspected upstream MediaPipe Tasks Core `1.2.2` `TaskRunner` creates `TasksStatsProtoLogger`; its remote client initializes Android DataTransport/CCT. That task-use metrics path conflicts with ASCEND's no-facial-telemetry requirement even though source inspection did not show photo/landmark payload submission.

A source Gradle task attempts to pin/check both AAR hashes, remove logger/telemetry classes, substitute upstream `TasksStatsDummyLogger`, and fail closed if DataTransport or telemetry-proto references remain. A local archive transformation and Java API spot-check were performed outside Gradle. **The Gradle task, resolved runtime graph, merged DEX, and network behavior have not been tested. Status remains BLOCKED.** Do not make a user-facing or release privacy guarantee until APK/AAB inspection and packet capture confirm the telemetry sender is absent and no face-derived data leaves device.

## Storage, encryption, deletion

- AES-GCM is used for structured payloads and accepted photos; the random data key is stored through `flutter_secure_storage` for Android Keystore-backed protection.
- Android app backup is disabled in source. Final merged manifest and actual backup/restore behavior are unverified.
- Single scan deletion removes its record and private photo; progress deletion removes scans/photos/check-ins; all-data deletion removes local rows/files, invalidates the configured RevenueCat customer-info cache, destroys/reinitializes the local data key, and returns to onboarding.
- CameraX temporary `CAP*.jpg` files are deleted in normal flows, best-effort at startup, and during all-data erase. Failure/forced termination cases are not device-tested.
- Flutter image-cache clearing is implemented for photo deletion; cache release behavior is not verified on device.
- Flash storage deletion is **not forensic secure erasure**. Flash translation layers, wear levelling, backups and storage behavior can retain recoverable remnants. ASCEND must not promise forensic erasure.
- No SQLite power-loss, corruption, rollback, Android Keystore loss, uninstall/reinstall, backup, or interrupted-delete experiment has run.

## Secrets, logs and access

No RevenueCat key, signing key or production product/entitlement identifier is embedded. Product and entitlement IDs and public RevenueCat Android SDK key use compile-time configuration. Release signing has no debug-key fallback. These are source observations only; embedded secret/debug-symbol scanning of an artifact is blocked because no artifact exists.

Native inference errors do not intentionally include image bytes or the file path. No logcat audit has run. Final audit must verify that Flutter, plugins, MediaPipe, billing and crash logs do not emit photos, landmarks, notes, credentials, purchase tokens or sensitive identifiers.

## Permissions / traffic evidence required before release

1. Build release and inspect the merged manifest (`aapt dump permissions`, bundle/APK manifest tooling); verify audio, shared-storage, location, contacts, exact-alarm and other unnecessary permissions are absent.
2. Inspect resolved Gradle/Pub dependency graphs and full SDK data practices; confirm the MediaPipe no-op substitution is the class actually loaded.
3. Inspect APK/AAB DEX/AAR contents for telemetry loggers, transport backends, debug code, credentials and unexpected endpoints.
4. Capture DNS/TLS/HTTP metadata and payload sizes during scan and non-scan flows. Use a network inspector/proxy only in a test environment; do not capture real photos or tokens in retained logs.
5. Verify offline scan and coaching, and separately characterize allowed purchase/restore traffic.
6. Verify delete controls for DB rows, encrypted photos, CameraX temporary files and image caches; document that this is logical deletion, not forensic flash erasure.
7. Have qualified privacy/legal review approve disclosures, model licensing and third-party SDK handling.

## Verification matrix

| Requirement | Exact procedure | Environment/version | Actual result | Status | Evidence path | Remaining issue / next action |
|---|---|---|---|---|---|---|
| Source data-flow and permissions review | Inspect scan, persistence, subscription, notification, manifest and native channel sources; record data entry, storage, deletion and network paths. | Workspace source snapshot 2026-11-05; no Flutter/Android tools. | Source paths and intended flows documented above; no runtime assertion. | PASS (source review only) | `lib/features/scan/`, `lib/data/`, `lib/core/security/`, `lib/features/subscription/`, `lib/features/notifications/`, Android manifest/native source. | Verify behavior from resolved dependency graph, merged manifest and installed release artifact. |
| MediaPipe task telemetry mitigation | Run `cd android && ./gradlew :app:patchMediaPipeTelemetry`; inspect transformed AAR and final DEX for logger, telemetry proto and DataTransport references; packet-capture task execution. | Gradle/JDK 17+/Android SDK absent; only a manual archive transformation was performed. | Manual transformed archive showed no targeted bytecode references; Gradle task/final DEX/runtime traffic not tested. | BLOCKED | `android/app/build.gradle.kts`; manual experiment not retained as release evidence. | Execute Gradle task, inspect APK/AAB, then capture final app traffic during repeated scans. |
| No facial data / telemetry leaves device | Install signed release artifact; capture DNS/TLS metadata and payload behavior during onboarding, scan, coaching, progress, delete, purchase and restore; correlate with SDK documentation. | No APK/device/proxy or billing setup. | No packet capture; cannot claim no transmission. | BLOCKED | No capture artifact. | Complete controlled network audit and document all destinations/purpose/observed fields. |
| Merged permissions and features | Build release; inspect merged manifest and `aapt dump permissions`; compare to source declarations/removal directives. | Android Gradle plugin/SDK absent. | Source manifest only; final merged permissions unknown. | BLOCKED | `android/app/src/main/AndroidManifest.xml`; no merged manifest. | Build and inspect; remove or justify unexpected permissions/features. |
| Encryption, deletion, backup and recovery | Run `flutter test test/secure_vault_test.dart` and DB migration tests; on device test Keystore loss, backup/restore, force-stop, cache/temp cleanup and per-scan/all-data erase. | Flutter/Dart/Android device absent. | Test source exists but has not run; device-level cases not run. | BLOCKED | `test/secure_vault_test.dart`, `test/local_database_test.dart`; no runtime artifact. | Run unit and device suites; record recovery and deletion results; avoid forensic-erasure promises. |
| Logs and release secrets | Exercise final release; inspect logcat and APK/AAB strings/DEX for photos, landmarks, notes, tokens, SDK keys, debug endpoints and test code. | No release artifact/device. | Source has no embedded production credentials by inspection; artifact scan and log review not run. | BLOCKED | `android/app/build.gradle.kts`, `lib/features/subscription/subscription_service.dart`; no artifact output. | Scan exact release artifacts and sanitized runtime logs. |
| Legal, model provenance and third-party SDK disclosures | Review model cards/redistribution terms, Pub/Gradle dependency graph and Play/privacy disclosures with qualified reviewers; record signed/date-approved findings. | No resolved lockfile, publisher details or reviewers supplied. | Upstream model-card source reviewed; no qualified approval or full dependency/license audit. | BLOCKED | `THIRD_PARTY_NOTICES.md`, `assets/models/README.md`; no approval record. | Complete SBOM/license review and qualified legal/store-policy approval before release. |

## Current disposition

Source architecture and some APIs/artifacts were manually inspected. No independent runtime/security audit, final artifact inspection, network capture, Android Keystore test, or legal approval has been performed. **All such gates remain BLOCKED or NOT TESTED.**
