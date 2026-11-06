# ASCEND source implementation audit

**Date:** 2026-11-05 (Asia/Kolkata)  
**Scope:** Current source tree under `/home/user`. This is a source audit, not a release certification.

## Executive result

The empty initial workspace has been populated with an Android-first Flutter implementation: consent onboarding, local rule-based coaching and 90-day plans, scan capture/quality gates, a native MediaPipe Face Landmarker bridge, local SQLite migrations, encrypted private photos and structured payloads, progress/deletion controls, RevenueCat integration scaffolding, optional local reminders, legal drafts, Android release scaffolding, and source tests.

**Acceptance is not verified.** No Flutter/Dart dependency resolution, analysis, test run, Gradle build, APK/AAB inspection, emulator/device test, purchase test, or final-artifact network capture could be run because Flutter, Dart, Gradle, ADB, and the Android SDK are absent. Only Java 11 is present; the project baseline requires Java 17+. Do not call this production-ready or release-ready.

## Implemented in source

- Consent-led 18+ onboarding and local preferences; initial preference and plan persistence now share one SQLite transaction.
- Rule-based local coach and persisted 90-day free/Pro plans. No generated AI results, diagnosis, identity/ethnicity inference, or attractiveness ranking.
- Front-camera-only scan consent, preview/discard, pixel checks, on-device Android MediaPipe landmarks, capture-geometry checks, one saved free scan, and a seven-day Pro rescan interval.
- Rejected/temporary camera captures are deleted in normal paths; CameraX `CAP*.jpg` leftovers are cleaned best-effort at startup and during data erasure. Accepted photos are AES-GCM encrypted before app-private persistence.
- SQLite schema v1/v2, foreign keys and indexes; user/plan/scan/progress payload encryption; key-loss handling; individual scan/check-in deletion, progress-history deletion, and typed `DELETE` whole-data erasure.
- RevenueCat purchase/restore/entitlement logic with publisher-supplied compile-time product IDs, entitlement ID, and public SDK key; no default prices, product IDs, or entitlement grants. Native Google Play subscription-management channel included.
- Optional local notifications; minSdk 24 reflects selected plugin requirements. Reminder failures are nonfatal to app startup.
- Android manifest and Gradle wrapper/release scaffold; no debug-signing fallback and no credentials checked in.
- Source tests now cover onboarding rendering, native-channel serialization/error mapping, geometry gates, local-plan limits, SQLite migrations, and AES-GCM/key-loss behavior. There are also Android unit-test sources for the MediaPipe no-op logger replacement.

## Privacy / telemetry finding and mitigation in source

Inspection of the pinned MediaPipe Tasks `tasks-core` artifact showed that its default `TaskRunner` unconditionally creates `TasksStatsProtoLogger`, which uses Android DataTransport/CCT to transmit task-use metrics. The inspected logger records task/session/performance/system metadata; the source path is not a photo or landmark upload API, but it is task-use telemetry and conflicts with ASCEND's no-facial-telemetry requirement.

The implementation therefore does **not** accept the upstream logger unchanged. `android/app/build.gradle.kts` is written to:

1. Pin MediaPipe Tasks Vision/Core `1.2.2` and check SHA-256 for both upstream AARs.
2. Remove the upstream logger factory, remote logger, and telemetry protobuf classes from the `tasks-core` AAR.
3. Substitute the upstream `TasksStatsDummyLogger` through an exact-signature local Java factory.
4. Fail closed if the pinned class layout changes or if DataTransport/telemetry-proto class references remain in the transformed AAR.
5. Include a JVM unit-test source asserting the factory returns the no-op logger.

This patch is **not executed or verified by Gradle** in this environment. A final release build, DEX/AAR inspection, and outbound network capture during/after scans are mandatory before claiming telemetry is blocked. The app also needs `INTERNET` for optional RevenueCat/Google Play billing; that permission does not itself establish which runtime requests occur.

## Checks actually performed

- Parsed the checked-in Android manifest/resource XML successfully with Python's XML parser.
- Parsed `pubspec.yaml`; a source-import scan found no missing local imports and no undeclared external Dart package imports.
- Recomputed the bundled model SHA-256 as `64184e229b263107bc2b804c6625db1341ff2bb731874b0bcc2fe6544e0bc9ff`; it matches the Android and Dart constants.
- Inspected the `.task` archive contents: face detector, face-landmark detector, geometry metadata, and blendshape model. Blendshape and facial transformation-matrix outputs are disabled in native options; only landmarks are returned to Dart.
- Queried Maven POMs and inspected the pinned MediaPipe Java bytecode with `javap` for FaceLandmarker builder methods, model path, image mode, landmark getters, and the upstream dummy logger.
- Reproduced the logger-class removal locally against the downloaded pinned `tasks-core` AAR; the patched class jar had no remaining DataTransport or MediaPipe telemetry-proto class references. Compiled the replacement Java factory with `javac` against that patched jar using a minimal Android `Context` stub. This is **not** an Android/Gradle build or device test.
- Inspected selected Pub package archives/metadata for RevenueCat purchase methods, notification APIs, CameraX temporary filename/path and manifest permissions, and minSdk requirements. CameraX `RECORD_AUDIO`, shared-storage permission, and required generic-camera feature are removed in the app manifest; camera and notification permissions remain as needed.

## Not run / not established

- `flutter pub get`, `flutter analyze`, `flutter test`, native JUnit, Gradle configuration/task execution, APK/AAB build, lint, R8, manifest merge, APK/DEX inspection, or signing.
- No `pubspec.lock` has been generated; resolved transitive Flutter dependencies and full license inventory are unknown.
- A clean-install onboarding/saved-plan integration-test source was added at `integration_test/app_flow_test.dart`; it has not been run and is not evidence of a passing flow.
- The evidence-oriented gate, device, security/privacy, release-checklist, and external-configuration documents are maintained under `docs/`; they explicitly mark unrun gates BLOCKED or NOT TESTED.
- No Android device/emulator scan, camera permission/lifecycle/orientation test, MediaPipe model-runtime compatibility test, CPU/memory/thermal test, or photo-deletion/cache/backup test.
- No data-loss/power-failure SQLite test or Android Keystore integration test.
- No Google Play Billing/RevenueCat test, purchase/restore/cancel/expiry test, actual store products/entitlement setup, or localized price check.
- No final-artifact packet capture to verify that MediaPipe telemetry is absent and facial photos/landmarks never leave the device.
- No full model redistribution/provenance or transitive license review.

## External configuration / release blockers

- Install Flutter 3.47.9 / Dart 3.13.7, Java 17+, Android SDK, and a supported test device/emulator; then resolve dependencies and generate/commit the lockfile.
- Replace placeholder Android application ID `com.ascend.coach` with the publisher-approved ID.
- Configure actual Google Play subscriptions and RevenueCat, then pass `ASCEND_RC_ANDROID_KEY`, `ASCEND_RC_MONTHLY_PRODUCT_ID`, `ASCEND_RC_ANNUAL_PRODUCT_ID`, and `ASCEND_RC_PRO_ENTITLEMENT_ID` through secure build configuration. No secret/service key belongs in the app or repository.
- Provide approved signing configuration out of band using the Gradle properties/environment variables documented in `README.md`. No signing material exists here.
- Complete publisher/legal review of the privacy/terms drafts and the MediaPipe model artifact/cards, then inspect all resolved dependency licenses.
- Run end-to-end storage/deletion, purchase lifecycle, R8, manifest permission, offline scan and network-isolation checks. Record results before release.

## Final disposition

Source implementation and manual source audit: **performed**.  
Static syntax/import and artifact/API spot checks: **partially performed**.  
Dart analysis and test results: **not available**.  
Android build/device/store/network results: **not available**.  
Release disposition: **IMPLEMENTATION-COMPLETE — VERIFICATION-PENDING**. Production readiness and release acceptance are not established; do not release until applicable gates have evidence and pass.
