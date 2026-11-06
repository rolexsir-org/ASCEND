# Third-party notices and provenance review

This file records the direct source inputs currently selected for ASCEND. It is not a complete generated dependency/license inventory; generate and review the full resolved-license report after dependency resolution and before distributing an APK/AAB.

## MediaPipe Face Landmarker model

- Artifact: `assets/models/face_landmarker_v1.task`
- Source: [versioned Google Cloud Storage model artifact](https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task)
- SHA-256: `64184e229b263107bc2b804c6625db1341ff2bb731874b0bcc2fe6544e0bc9ff`
- Model cards: [MediaPipe Face Mesh V2](https://storage.googleapis.com/mediapipe-assets/Model%20Card%20MediaPipe%20Face%20Mesh%20V2.pdf), [BlazeFace Short Range](https://storage.googleapis.com/mediapipe-assets/MediaPipe%20BlazeFace%20Model%20Card%20(Short%20Range).pdf), and [Blendshape V2](https://storage.googleapis.com/mediapipe-assets/Model%20Card%20Blendshape%20V2.pdf). The `.task` archive contains detector, landmark, geometry metadata, and blendshape model files; blendshape output is explicitly disabled in ASCEND. Upstream cards state Apache-2.0 licensing and include intended-use and evaluation limitations.
- Use in ASCEND: bundled Android asset, checksum-validated locally before inference; not fetched or updated at runtime; no raw landmarks are transmitted.
- Status: exact artifact checksum is recorded, but legal/provenance review of the model card, derived components, attribution requirements, and redistribution terms has **not** been signed off. Do not distribute publicly until complete.

## Android native libraries (direct dependencies)

- `com.google.mediapipe:tasks-vision:1.2.2` — SHA-256 `114b3dce25bbafa0f93904a2294cdc3576b415c879ed60bb1aa945183d0dee08`; Maven metadata/POM identifies MediaPipe Authors and Apache License 2.0. API signatures were inspected from the pinned AAR. The upstream `tasks-core` source unconditionally initializes a `TasksStatsProtoLogger` / DataTransport path.
- `com.google.mediapipe:tasks-core:1.2.2` — SHA-256 `7ed8d0d473af0ad62914401226199f595683001a6930f0f46a0d32af70eeb048`; its AAR is transformed at Gradle build time. SHA-256 checks in the Gradle task fail closed if either upstream artifact changes. ASCEND's Gradle build source removes that factory, remote logger classes, and telemetry protobufs, substitutes the upstream no-op `TasksStatsDummyLogger`, and refuses to build if DataTransport or telemetry-proto references remain. The patch has not been run by Gradle, and the resulting APK's network behavior has not been packet-capture verified; keep release blocked until it is.
- The pinned `tasks-core` AAR and `tasks-vision` AAR were manually inspected with `javap`; the FaceLandmarker builder, model asset path, image mode, landmark getters, and no-op logger factory used by source are present in 1.2.2. This does not verify model-file compatibility, app buildability, runtime behavior, or network traffic.
- `androidx.exifinterface:exifinterface:1.4.2` — AndroidX / AOSP, Apache License 2.0.

## Flutter packages

Direct Flutter packages are pinned in `pubspec.yaml`. Their transitive dependency graph and applicable notice texts have not been resolved in this environment. Before distribution, run `flutter pub get`, enumerate every shipped package and native artifact, retain required licenses/notices, and attach the resulting inventory to the release review.
