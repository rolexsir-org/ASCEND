# ASCEND external configuration and unblock steps

**Status:** No production account, credentials, application ID approval, signing key, store product or legal approval is configured in this workspace. Do not enter real secrets into source files or checked-in reports.

## Required resources

| Resource | Current status | What it unblocks | Safe setup / evidence |
|---|---|---|---|
| Flutter 3.47.9 / Dart 3.13.7 | BLOCKED: not installed | Pub resolution, formatting, analysis, Dart/widget/integration tests | Install from official Flutter archive; record `flutter --version`, `dart --version`; do not add SDK path to source. |
| Java 17+ | BLOCKED: Java 11 available | Current AGP/Gradle configuration and Android tasks | Install supported JDK 17+; record `java -version`; keep `JAVA_HOME` local/CI-only. |
| Android SDK / build-tools / NDK | BLOCKED: absent | Gradle configuration, debug/release APK/AAB, manifest/R8/artifact inspection | Install Android Studio/command-line SDK components required by pinned Flutter; accept licenses; store `sdk.dir` only in ignored `android/local.properties`. |
| Emulator / physical Android devices | BLOCKED: none attached/available | Camera, lifecycle, performance, storage, notification and end-to-end testing | Use a disposable emulator plus representative physical devices; record sanitized model, Android version/API, ABI and build hashes in `DEVICE_TESTING.md`. |
| Approved application ID | BLOCKED: `com.ascend.coach` is a placeholder | Play registration, package/signing and RevenueCat linkage | Publisher must approve a globally unique ID; set Gradle property `ASCEND_APPLICATION_ID`; align namespace/package if required; record approval, not a secret. |
| Google Play Console application and subscription products | BLOCKED: not created/configured | Actual monthly/annual purchase offers, localized prices, renewals, Play test track | Create publisher-owned products and trial terms in Play Console; use real returned product IDs; do not invent values in this repository. |
| RevenueCat project and Play linkage | BLOCKED: no project | Entitlement verification, offerings, restore and customer-info flow | Create project; link approved Play app/service credentials using RevenueCat's secure dashboard; configure the real entitlement and offerings. Never put service credentials in the app. |
| RevenueCat public Android SDK key | BLOCKED: not supplied | RevenueCat SDK initialization and sandbox verification | Supply only the public Android SDK key through secure CI/local build define `ASCEND_RC_ANDROID_KEY`; never include secret/service keys. |
| Exact RevenueCat product/entitlement IDs | BLOCKED: publisher values unknown | Product filtering and entitlement gate | Supply actual values using `ASCEND_RC_MONTHLY_PRODUCT_ID`, `ASCEND_RC_ANNUAL_PRODUCT_ID`, `ASCEND_RC_PRO_ENTITLEMENT_ID`; there are deliberately no defaults in source. |
| Approved Android signing keystore | BLOCKED: none present | Authorized release APK/AAB signing | Generate/obtain publisher-approved key through secure release process; do not upload private key or passwords to this workspace. Pass `ASCEND_KEYSTORE_PATH`, `ASCEND_KEYSTORE_PASSWORD`, `ASCEND_KEY_ALIAS`, `ASCEND_KEY_PASSWORD` through protected Gradle properties/secrets. Never log them. |
| Legal publisher details / approval | BLOCKED: drafts only | Public privacy policy, terms, store disclosure and release | Publisher/legal reviewer supplies entity/contact/effective date/jurisdiction and approves data practices. Record approval reference/date, not private case files. |
| Model redistribution/provenance approval | BLOCKED: review pending | Publicly bundling the MediaPipe model artifact | Review model bundle source/hash, all included components/cards, Apache-2.0 terms, notices, intended-use limits and redistribution rights with qualified reviewer. Record disposition. |
| Resolved dependency/license report | BLOCKED: no lockfile or pub get | Reproducible dependency tree, CVE and notice review | After Flutter install run `flutter pub get`, commit lockfile, inspect Pub/Gradle graphs and generate full shipped dependency/license inventory. |

## Build configuration (no real values in docs)

Dart compile-time defines consumed by source:

- `ASCEND_RC_ANDROID_KEY`
- `ASCEND_RC_MONTHLY_PRODUCT_ID`
- `ASCEND_RC_ANNUAL_PRODUCT_ID`
- `ASCEND_RC_PRO_ENTITLEMENT_ID`

Gradle properties/environment variables consumed by the Android app:

- `ASCEND_APPLICATION_ID`
- `ASCEND_KEYSTORE_PATH`
- `ASCEND_KEYSTORE_PASSWORD`
- `ASCEND_KEY_ALIAS`
- `ASCEND_KEY_PASSWORD`

Use protected CI secret storage or ignored local configuration. Do not paste values into shell history, terminal transcripts, issue trackers, or this file. Prefer CI masking; redact command output before retention. `android/local.properties` is ignored and contains machine-specific SDK/Flutter paths only.

## Steps to unblock source verification

1. Install the pinned Flutter SDK and Java 17+; verify version output.
2. Install Android SDK/build tools; configure local-only `android/local.properties`.
3. Run `flutter pub get`; resolve dependency errors and commit the generated `pubspec.lock`.
4. Run format, analyzer, Dart/widget tests and Gradle native unit test. Save sanitized full logs under approved evidence storage.
5. Run `patchMediaPipeTelemetry`; inspect transformed AAR for logger/telemetry classes; verify no-op test and dependency graph.
6. Build debug APK; inspect manifest and launch on emulator. Execute integration and device matrix.
7. Obtain publisher/Play/RevenueCat configurations; use test account and test track for purchase lifecycle.
8. Inject approved signing only in secure release pipeline; build release APK/AAB; inspect signatures, R8, permissions, ABI, secrets and debug artifacts.
9. Capture final-artifact network behavior during scan and billing. Do not infer privacy from source-only checks.
10. Complete qualified legal/model/dependency review and update every status in `PRODUCTION_READINESS.md`.

Missing resources block only the dependent checks. They do not authorize marking those checks PASS or inventing an approval/result.
