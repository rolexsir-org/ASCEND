# Bundled face-landmarker model

- File: `face_landmarker_v1.task`
- Source: https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task
- SHA-256: `64184e229b263107bc2b804c6625db1341ff2bb731874b0bcc2fe6544e0bc9ff`
- Size at source capture: approximately 3.6 MiB.
- Runtime: Android MediaPipe Tasks Vision, pinned in `android/app/build.gradle.kts`.
- Loading: included only as an Android native asset; verified by SHA-256 before the native landmarker is created. Never downloaded, copied to shared storage, or sent to a remote service by ASCEND source.

The archive contains face detector, face landmark, geometry metadata, and blendshape model components. ASCEND explicitly disables blendshape output and uses landmarks only. Upstream model cards are linked in `../../THIRD_PARTY_NOTICES.md`; they indicate Apache-2.0 licensing and document intended-use limitations. Redistribution/provenance and notice review is still pending; this asset is included for source implementation, not authorization to publish it. Complete legal review before release.
