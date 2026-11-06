# ASCEND release checklist

**Current decision: DO NOT RELEASE.** No release artifact exists. Every checkbox is initially unchecked. A checklist item can be checked only when evidence is attached and reviewed.

## Source and dependency reproducibility

- [ ] Flutter 3.47.9 / Dart 3.13.7 installed and recorded.
- [ ] `flutter pub get` succeeds; `pubspec.lock` committed and reviewed.
- [ ] `dart format --output=none --set-exit-if-changed lib test integration_test` exits 0.
- [ ] `flutter analyze` exits 0; all warnings resolved or explicitly justified without blanket suppression.
- [ ] `flutter test` passes; full output retained.
- [ ] Native JVM test passes: `cd android && ./gradlew :app:testDebugUnitTest`.
- [ ] Integration tests pass on a recorded disposable emulator/device.
- [ ] Dependency graph, versions, repositories, transitive dependencies and complete license/SBOM inventory reviewed.

## Android build and artifacts

- [ ] Java 17+, Android SDK/build-tools and required NDK installed and recorded.
- [ ] Gradle wrapper/configuration tasks succeed; `patchMediaPipeTelemetry` executes and transformed AAR is inspected.
- [ ] Debug APK builds and launches.
- [ ] Release APK builds with approved signing.
- [ ] Release AAB builds with approved signing.
- [ ] R8/minification and resource shrinking execute; no relevant warnings/errors; ProGuard rules validated on device.
- [ ] Merged release manifest inspected; permissions/features are minimal and accurate.
- [ ] APK/AAB structure, assets, DEX, native libraries, ABIs, symbols and resource output inspected.
- [ ] Signing certificate fingerprint verified; private signing material never copied into repository/logs/reports.
- [ ] Secret, debug endpoint, mock-data and development-feature scan passes on final artifacts.
- [ ] Final APK/AAB SHA-256 and build logs retained in approved artifact storage.

## Product and physical-device checks

- [ ] Device matrix and camera/permission/lifecycle/orientation cases in `DEVICE_TESTING.md` executed.
- [ ] MediaPipe bundled model checksum verified in artifact; actual task/model compatibility, face gates and unsupported-device behavior pass.
- [ ] CPU/memory/battery/thermal/low-memory behavior measured on representative low-resource and current devices.
- [ ] Local/offline functionality tested; notification denial and app restart/recovery tested.
- [ ] Merged manifest confirms no recording, shared storage, location, contacts, exact alarm or other unneeded capability.

## Data and privacy

- [ ] Fresh DB, every supported migration, foreign keys, corrupted DB handling and transaction interruption tests pass.
- [ ] Photo encryption, Keystore loss, per-scan deletion, all-data deletion, cache/temp cleanup and app restart recovery pass on device.
- [ ] Backup disabled as intended; uninstall/reinstall and store restore behavior documented.
- [ ] Final APK/AAB has no reachable MediaPipe telemetry logger/DataTransport path; packet capture during scan and other flows confirms no facial data/telemetry leaves device.
- [ ] All network destinations/payload purposes documented; billing-only traffic independently inspected.
- [ ] Logs inspected for sensitive data.
- [ ] Deletion wording is logical deletion only; no forensic secure-erase guarantee.

## Monetization and external approvals

- [ ] Publisher-approved application ID configured.
- [ ] Google Play application, subscriptions, trial eligibility, metadata and testing track configured.
- [ ] RevenueCat project, entitlement, store linkage and public Android SDK key configured securely.
- [ ] Purchase success/cancel/fail/pending/acknowledgement/renewal/expiry/cancel/grace/offline/restore tested with Play test account.
- [ ] Prices and offers verified from actual Play-returned products in relevant locales.
- [ ] Subscription-management navigation and billing unavailable state tested.
- [ ] Approved release signing keys accessible only to authorized secure build pipeline.
- [ ] Privacy policy, terms, publisher contact/effective date and Google Play disclosures legally reviewed and published.
- [ ] Model provenance/redistribution and all dependency licenses reviewed and approved.

## Evidence and authorization

- [ ] `PRODUCTION_READINESS.md` updated for every gate with exact command/procedure, environment, result, evidence path and remaining risk.
- [ ] `DEVICE_TESTING.md`, `SECURITY_PRIVACY_AUDIT.md`, and `EXTERNAL_CONFIGURATION.md` updated with actual results.
- [ ] Independent reviewer approves release artifact and unresolved risks.
- [ ] Release owner explicitly authorizes publication.

No release is authorized until every applicable release-critical item above has evidence. A successful compilation alone does not satisfy device, privacy, billing, legal, or deletion gates.
