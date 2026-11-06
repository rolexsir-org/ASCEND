# MediaPipe Tasks resolves portions of its task graph and native bindings reflectively.
-keep class com.google.mediapipe.tasks.core.** { *; }
-keep class com.google.mediapipe.tasks.vision.facelandmarker.** { *; }
-keep class com.google.mediapipe.framework.** { *; }
-keepattributes *Annotation*
# MediaPipe Tasks Vision marks its LiteRT-LM image-embedder backend optional;
# ASCEND uses FaceLandmarker only and does not package that backend.
-dontwarn com.google.ai.edge.litertlm.**
-dontwarn com.google.mediapipe.proto.**
