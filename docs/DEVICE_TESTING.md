# ASCEND Android device test plan and results

**Current result:** **BLOCKED — no Flutter/Android SDK, emulator, or physical test device available.** There are no device results in this document. Do not infer compatibility from Java API inspection or compilation of a helper class.

## Device inventory

| Device / model | Android version / API | RAM / ABI | Build fingerprint or approved identifier | Test date | Status |
|---|---|---|---|---|---|
| Not supplied / not available | Unknown | Unknown | Not recorded | Not run | BLOCKED |

Do not add a model, OS version, or result until an actual test is performed. Avoid recording serial numbers or other unnecessary personal identifiers.

## Reproducible setup

1. Install Flutter 3.47.9 / Dart 3.13.7, Java 17+, Android SDK/build-tools, and a supported emulator or physical device.
2. Run `flutter pub get`, `dart format --output=none --set-exit-if-changed lib test integration_test`, `flutter analyze`, `flutter test`, and the native JVM test first. Resolve failures before device execution.
3. Use a **disposable** emulator or test device; clear the app's test data or uninstall before onboarding persistence tests. Do not erase a user's actual ASCEND data.
4. Record model/device/OS/API/ABI, build variant and hash, camera configuration, ambient lighting, network state, and actual outcome. Keep logs free of photos, tokens, purchase identifiers and private keys.
5. Run the integration flow with `flutter test integration_test/app_flow_test.dart -d <device-id>`; capture complete output and store it with the test run.
6. Run debug then release builds separately. Repeat privacy tests against the exact release APK/AAB, not only debug.

## Required scenarios

| Requirement / scenario | Exact procedure | Environment/version | Actual result | Status | Evidence path | Remaining issue / next action |
|---|---|---|---|---|---|---|
| Fresh install, consent, saved plan navigation | `flutter test integration_test/app_flow_test.dart -d <device-id>` after clearing app data; complete onboarding, navigate from Coach to Plan and verify populated plan content. | Flutter 3.47.9 / Dart 3.13.7 required; emulator/device and Android version not available. | Test source added; command not run. | BLOCKED | `integration_test/app_flow_test.dart`; output not available. | Install toolchain and run on disposable device; retain sanitized output and environment. |
| Camera permission allow / deny / revoke | Start scan with permission allowed; repeat denial, permanent denial and OS Settings revocation. Verify denial is explained and scan remains unavailable without blocking other screens. | Android device/OS unknown; not available. | Not run. | BLOCKED | No result artifact. | Execute on at least one emulator and physical device; record permission prompts/settings behavior. |
| Front-camera orientation / mirroring | Compare preview and captured-image orientation across portrait/landscape and front-camera mirror behavior; verify geometry uses upright bitmap. | Camera hardware/device/OS unknown; not available. | Not run. | BLOCKED | No result artifact. | Execute with known orientation targets; record sample output without retaining personal photos. |
| Camera lifecycle / interruptions | Background/foreground, lock screen, incoming interruption, route away, rotate, process kill and recreation during preview/capture; inspect controller disposal and temporary capture cleanup. | Android device/OS unknown; not available. | Not run. | BLOCKED | No result artifact. | Run lifecycle matrix and inspect sanitized logcat and cache. |
| Temporary paths / cleanup | Confirm CameraX path remains under app-private cache; reject external path in native channel; test discard/reject/restart/app-kill cleanup of `CAP*.jpg`; inspect no public storage. | Android device/OS unknown; not available. | Not run. | BLOCKED | No result artifact. | Capture app-private path checks and before/after cache inventory. |
| Pixel / face gates | Test no face, multiple faces, off-center, too-small/large, dark/bright, blur, head turn, partial occlusion and accepted single face. Verify rejected images are not retained. | Device, test chart/image set and runtime unknown; not available. | Not run. | BLOCKED | No result artifact. | Use controlled consented test images; preserve no private facial image in evidence. |
| MediaPipe model/runtime | Validate pinned AAR checksums, runtime/model compatibility, model checksum failure, no-op logger, supported/unsupported devices and native library loading. | Android build tools/device unknown; not available. | Source/API spot-check only; no Gradle or device run. | BLOCKED | `android/app/build.gradle.kts`; manual AAR notes in session only. | Run pinned Gradle patch task and install built APK; inspect runtime and final DEX. |
| Performance / low-resource | Record CPU, peak memory, duration, battery/thermal conditions, ANR/OOM behavior and repeated-scan recovery on lower-resource hardware. | Representative device/model/API unavailable. | Not run. | BLOCKED | No result artifact. | Test current and lower-resource physical devices and record measurements. |
| Offline operation | Disable networking; complete onboarding, local coaching, local image checks/landmarks, progress, deletion and reminder preferences. Verify billing unavailability does not alter local scan behavior. | Android device and network capture unavailable. | Not run. | BLOCKED | No result artifact. | Run airplane-mode scenario; retain sanitized logs and separately test final traffic. |
| Notifications | Deny `POST_NOTIFICATIONS`, enable/disable, schedule inexact reminders, reboot, change timezone; verify notification content contains no photos/facial info. | Android device/OS unavailable. | Not run. | BLOCKED | No result artifact. | Run on supported API levels with denied and granted notification states. |
| Storage restart/recovery | Force-stop during onboarding/plan write/photo save/delete; restart and inspect rows, key recovery, orphan cleanup and user-facing state. | Android device/OS unavailable. | Not run. | BLOCKED | No result artifact. | Use disposable data; collect DB/cache state and verify no silent data replacement. |
| Release-specific behavior | Install exact minified/symbol-stripped APK; verify MediaPipe, billing, notifications, icons, lifecycle and errors under R8. | No release artifact or device. | Not run. | BLOCKED | No APK/AAB. | Build, hash and inspect release artifact before executing this row. |

## Result recording template

For each executed scenario add:

- Exact command/manual steps and preconditions.
- Device model, Android version/API, ABI, app build hash, and test date.
- Expected result and observed result.
- Pass / fail / blocked / not tested.
- Sanitized log/artifact path; do not include credentials, private photos or personal data.
- Defect ID, root cause and retest evidence.

The absence of a device is a blocker, not a pass. Compilation alone is not device verification.
