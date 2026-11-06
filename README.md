# ASCEND

**Build yourself. Track your progress. Ascend.**

ASCEND is an Android-first Flutter app for user-selected grooming, style, and habit goals. This repository now contains a working source implementation, including consent-led onboarding, a local 90-day plan, progress and deletion flows, on-device image/landmark analysis, encrypted app-private photo storage, SQLite schema migrations, a RevenueCat integration boundary, and optional local reminders.

> **Verification status:** source implementation only. Flutter, Dart, Gradle, Android SDK, and ADB are not installed in the current workspace. `flutter pub get`, static analysis, tests, Android builds, and device/network tests have **not** been run. Do not treat this source tree as a verified release candidate.
>
> Readiness records: [production gate ledger](docs/PRODUCTION_READINESS.md), [device test plan](docs/DEVICE_TESTING.md), [security and privacy audit](docs/SECURITY_PRIVACY_AUDIT.md), [release checklist](docs/RELEASE_CHECKLIST.md), and [external configuration](docs/EXTERNAL_CONFIGURATION.md). Source-only check evidence: `docs/evidence/source_static_checks.txt`.

## What is implemented in source

- **Onboarding and consent:** age confirmation (18+), user-selected goals, grooming preferences, available time, privacy consent, and public privacy/terms screens. Camera consent is separately shown before every scan flow.
- **Local coaching:** deterministic, rule-based routines; one task per day in the free plan and at most three in the Pro plan, bounded by the selected daily time. No generative AI or appearance score is used. Regenerated plans retain earlier plans.
- **Scan flow:** explicit consent, front-camera-only capture, preview and discard/retake, pixel-quality checks, MediaPipe Face Landmarker on Android, face-count/framing/landmark checks, and no persistence of rejected captures. Free scan allowance is one saved scan; Pro rescans are gated to seven-day intervals. These limits are source behavior and remain untested.
- **Facial-data boundary:** only normalized MediaPipe landmarks are returned to Flutter in process memory. They are reduced to capture geometry for an accepted scan. The raw landmark array and temporary capture file are not written as scan data. There is no remote face-analysis client, upload endpoint, facial telemetry, identity inference, demographic inference, attractiveness ranking, or diagnosis.
- **Local data:** SQLite schema versions 1–2 with explicit index migration and foreign keys. Structured user payloads are encrypted with AES-GCM using a key held through `flutter_secure_storage`; photos are AES-256-GCM encrypted before app-private persistence. CameraX's transient `CAP*.jpg` files are cleaned on a best-effort basis at startup after interrupted flows and during all-data erasure. Individual scan/photo deletion, progress-history deletion, and typed `DELETE` all-data erasure are implemented in source.
- **Subscriptions:** RevenueCat purchase/restore logic uses Google Play-returned products/prices, checks a named entitlement, and has native subscription-management navigation. No price, API key, or verified entitlement is fabricated. Play products, RevenueCat configuration, and signing are external setup.
- **Reminders:** optional local notification scheduling with notification permission handling and timezone support; Pro gating is checked in the UI/service flow.
- **Android:** native method-channel handlers for on-device MediaPipe and Google Play subscription management; camera/notification permissions; private backup disabled; cleartext traffic disabled; release minification rules; a Gradle wrapper and release-signing hooks that do not fall back to a debug key.
- **Tests:** source tests cover onboarding rendering with fake app services, channel argument/result/error mapping, face-geometry acceptance, local coach task caps, SQLite creation/migration, and AES-GCM/key-loss behavior. An Android integration test source covers consent onboarding through opening the persisted plan on a fresh install. Dart, native, and integration tests have not been executed.

## Architecture

- `lib/app/`: service initialization, Riverpod providers, GoRouter routes, app root.
- `lib/domain/`: local user, plan, scan, and progress data models.
- `lib/data/`: SQLite migrations and repository transactions.
- `lib/core/security/`: encrypted local payload/photo storage.
- `lib/features/`: onboarding, scan, local coach, plan, progress, subscription, reminders, settings, and legal UI.
- `android/app/src/main/kotlin/com/ascend/coach/MainActivity.kt`: serial local-image inference and store-management platform channels.
- `assets/models/face_landmarker_v1.task`: versioned model asset used only in the native Android asset bundle; not declared as a Flutter asset and not downloaded at runtime.

The Android handler accepts a path only from app-private cache/files directories, bounds the image size, applies EXIF orientation, validates the bundled model SHA-256 before loading it, and returns landmarks only to the Flutter process. An important upstream caveat: MediaPipe Tasks creates Google DataTransport usage metrics by default. The Android Gradle source therefore patches the pinned `tasks-core` AAR to replace `TasksStatsLoggerFactory` with MediaPipe's upstream no-op `TasksStatsDummyLogger`, removes the remote logger classes and telemetry protobufs, and fails the build if DataTransport or telemetry-proto references remain in the patched AAR. A native unit test asserts the replacement returns only the no-op logger. This privacy patch is source-implemented and independently bytecode-inspected, but the Gradle build and final APK network behavior are **not yet verified**; packet-capture tests remain a release blocker. The Android manifest includes `INTERNET` for optional RevenueCat/Google Play billing only; it does not grant broad storage, location, microphone, or contacts access.

## Model and third-party provenance

- Model artifact: `https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task`
- Expected SHA-256: `64184e229b263107bc2b804c6625db1341ff2bb731874b0bcc2fe6544e0bc9ff`
- Android runtime pin: `com.google.mediapipe:tasks-vision:1.2.2` with `tasks-core` patched by `patchMediaPipeTelemetry` (Maven metadata and Java API signatures were checked; no Gradle dependency resolution/build has run).
- Artifact/model-card and runtime notices: see `THIRD_PARTY_NOTICES.md` and `assets/models/README.md`.

The model card reports Apache-2.0 licensing and intended-use limitations. **A full redistribution/provenance and applicable model-terms review has not been completed. Public distribution must wait for that review.** The pinned runtime's API/device compatibility and release R8 behavior are also unverified.

## Toolchain and first run

The project baseline is Flutter **3.47.9** / Dart **3.13.7**. Install the pinned Flutter SDK, Java 17+, and an Android SDK with a supported emulator/device. Then, from this project root:

```sh
flutter --version
flutter pub get
flutter analyze
flutter test
flutter run
```

`flutter pub get` is expected to create `android/local.properties`, which points Gradle at the local Flutter SDK. No local SDK path is committed. The default Android application ID (`com.ascend.coach`) is a placeholder and must be replaced with the publisher-approved Play Store ID before release.

## Android / store release configuration

1. Review and replace the Android application ID using `-PASCEND_APPLICATION_ID=your.publisher.id` (or the matching Gradle property in local configuration); keep the Kotlin namespace aligned if it changes.
2. Create the actual Google Play subscription products and RevenueCat entitlement, then supply their exact publisher-selected identifiers through `ASCEND_RC_MONTHLY_PRODUCT_ID`, `ASCEND_RC_ANNUAL_PRODUCT_ID`, and `ASCEND_RC_PRO_ENTITLEMENT_ID`. No default product or entitlement IDs are baked in; the integration stays unavailable until all configuration is supplied.
3. Supply the RevenueCat **public Android SDK key** via `--dart-define=ASCEND_RC_ANDROID_KEY=...` (and the three IDs via matching `--dart-define` values). Never use a secret/service key in the client, and never commit any credential.
4. Supply approved signing information out of band through Gradle properties or environment variables: `ASCEND_KEYSTORE_PATH`, `ASCEND_KEYSTORE_PASSWORD`, `ASCEND_KEY_ALIAS`, and `ASCEND_KEY_PASSWORD`. Release signing deliberately does not fall back to debug credentials. No signing keys are included.
5. Build and verify only after configuration, on the pinned Flutter/JDK/AGP toolchain. Inspect the merged manifest, release dependency/license inventory, R8 output, Play purchase lifecycle, restore/cancel flows, and data/network behavior. Verify that scans work offline and that no face data reaches network services.
6. Complete legal review of the privacy policy/terms drafts and add publisher identity, effective date, jurisdiction, contact, store disclosures, and appropriate retention/contact details before public release.

Gradle pins follow Flutter 3.47.9's current Android template: Gradle 9.3.1, Android Gradle Plugin 9.1.0, and Kotlin plugin 2.4.0. The app sets Android `minSdk` to 24 to meet the selected notifications and secure-storage plugins, and enables Java core-library desugaring. The current environment has only Java 11; these files have not been compiled.

## Current limitations / acceptance blockers

- No `pubspec.lock` has been generated. No analysis, Dart test run, dependency resolution, Android Gradle build, APK/AAB inspection, emulator/device run, purchase sandbox test, or final-artifact network/privacy audit has been performed.
- Camera orientation, temporary-file path behavior, MediaPipe model/runtime compatibility, CPU/memory/thermal performance, and R8 release execution need device testing.
- SQLite and encrypted-photo deletion logic need migration, power-loss, cache, backup, and recovery tests. File deletion is not a forensic secure-erase guarantee on flash storage.
- No Play products, RevenueCat project/entitlement, approved application ID, public SDK key, signing keystore, or store listing are configured.
- Privacy policy and terms are drafts. Model redistribution/legal review and full transitive dependency-license review remain open.
- Do not represent the app as production-verified or release-ready until these checks pass and are documented.
