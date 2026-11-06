import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.security.MessageDigest
import java.util.zip.ZipEntry
import java.util.zip.ZipFile
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val applicationIdFromProperty = providers.gradleProperty("ASCEND_APPLICATION_ID").orNull ?: "com.ascend.coach"
val releaseStorePath = providers.gradleProperty("ASCEND_KEYSTORE_PATH").orNull
    ?: System.getenv("ASCEND_KEYSTORE_PATH")
val releaseStorePassword = providers.gradleProperty("ASCEND_KEYSTORE_PASSWORD").orNull
    ?: System.getenv("ASCEND_KEYSTORE_PASSWORD")
val releaseKeyAlias = providers.gradleProperty("ASCEND_KEY_ALIAS").orNull
    ?: System.getenv("ASCEND_KEY_ALIAS")
val releaseKeyPassword = providers.gradleProperty("ASCEND_KEY_PASSWORD").orNull
    ?: System.getenv("ASCEND_KEY_PASSWORD")
val releaseSigningConfigured = !releaseStorePath.isNullOrBlank() &&
    !releaseStorePassword.isNullOrBlank() && !releaseKeyAlias.isNullOrBlank() && !releaseKeyPassword.isNullOrBlank()

// MediaPipe Tasks initializes Google DataTransport metrics unconditionally in its
// TaskRunner. Patch the pinned tasks-core AAR to select its own no-op logger and
// remove the unreachable remote logger implementation before it enters the app.
val mediaPipeCoreUpstream by configurations.creating {
    isCanBeConsumed = false
    isCanBeResolved = true
    isTransitive = false
}
val mediaPipeVisionUpstream by configurations.creating {
    isCanBeConsumed = false
    isCanBeResolved = true
    isTransitive = false
}
val patchedMediaPipeCoreFile = layout.buildDirectory.file(
    "generated/mediapipe/tasks-core-1.2.2-no-telemetry.aar",
)
val patchMediaPipeTelemetry = tasks.register("patchMediaPipeTelemetry") {
    inputs.file(provider { mediaPipeCoreUpstream.singleFile })
    inputs.file(provider { mediaPipeVisionUpstream.singleFile })
    outputs.file(patchedMediaPipeCoreFile)
    doLast {
        fun sha256(file: File): String = MessageDigest.getInstance("SHA-256")
            .digest(file.readBytes()).joinToString("") { byte -> "%02x".format(byte) }
        val sourceAar = mediaPipeCoreUpstream.singleFile
        val visionAar = mediaPipeVisionUpstream.singleFile
        check(sha256(sourceAar) == "7ed8d0d473af0ad62914401226199f595683001a6930f0f46a0d32af70eeb048") {
            "Pinned MediaPipe tasks-core artifact checksum changed; refusing to build."
        }
        check(sha256(visionAar) == "114b3dce25bbafa0f93904a2294cdc3576b415c879ed60bb1aa945183d0dee08") {
            "Pinned MediaPipe tasks-vision artifact checksum changed; refusing to build."
        }
        val outputAar = patchedMediaPipeCoreFile.get().asFile
        outputAar.parentFile.mkdirs()
        val removedClassNames = setOf(
            "com/google/mediapipe/tasks/core/logging/TasksStatsLoggerFactory.class",
            "com/google/mediapipe/tasks/core/logging/TasksStatsProtoLogger.class",
            "com/google/mediapipe/tasks/core/logging/RemoteLoggingClient.class",
            "com/google/mediapipe/tasks/core/logging/LoggingClient.class",
            "com/google/mediapipe/proto/MediaPipeLoggingProto.class",
            "com/google/mediapipe/proto/MediaPipeLoggingEnumsProto.class",
        )
        val removedPrefixes = listOf(
            "com/google/mediapipe/tasks/core/logging/TasksStatsProtoLogger$",
            "com/google/mediapipe/tasks/core/logging/TasksStatsLoggerFactory$",
            "com/google/mediapipe/tasks/core/logging/RemoteLoggingClient$",
            "com/google/mediapipe/tasks/core/logging/LoggingClient$",
            "com/google/mediapipe/proto/MediaPipeLoggingProto$",
            "com/google/mediapipe/proto/MediaPipeLoggingEnumsProto$",
        )
        var factoryFound = false
        var dummyLoggerFound = false
        var patchedClasses = ByteArray(0)
        ZipFile(sourceAar).use { aar ->
            val classesEntry = aar.getEntry("classes.jar")
                ?: error("Pinned MediaPipe tasks-core AAR has no classes.jar; telemetry patch cannot continue.")
            val originalClasses = aar.getInputStream(classesEntry).use { it.readBytes() }
            val outputBytes = ByteArrayOutputStream()
            ZipInputStream(ByteArrayInputStream(originalClasses)).use { input ->
                ZipOutputStream(outputBytes).use { output ->
                    while (true) {
                        val entry = input.nextEntry ?: break
                        val name = entry.name
                        if (name == "com/google/mediapipe/tasks/core/logging/TasksStatsDummyLogger.class") {
                            dummyLoggerFound = true
                        }
                        val remove = name in removedClassNames || removedPrefixes.any { prefix -> name.startsWith(prefix) }
                        if (name == "com/google/mediapipe/tasks/core/logging/TasksStatsLoggerFactory.class") {
                            factoryFound = true
                        }
                        if (!remove) {
                            output.putNextEntry(ZipEntry(name))
                            input.copyTo(output)
                            output.closeEntry()
                        }
                        input.closeEntry()
                    }
                }
            }
            check(factoryFound) { "Pinned MediaPipe tasks-core layout changed; refusing an unpatched telemetry build." }
            check(dummyLoggerFound) { "The pinned MediaPipe no-op logger is missing; refusing to build." }
            patchedClasses = outputBytes.toByteArray()
        }

        // Fail closed if the patched archive still contains a class with a
        // DataTransport reference. The app's separate Play/RevenueCat billing
        // dependencies remain intact; only MediaPipe's telemetry path is removed.
        ZipInputStream(ByteArrayInputStream(patchedClasses)).use { input ->
            while (true) {
                val entry = input.nextEntry ?: break
                if (entry.name.endsWith(".class")) {
                    val bytes = input.readBytes()
                    val classText = String(bytes, Charsets.ISO_8859_1)
                    check(!classText.contains("com/google/android/datatransport")) {
                        "MediaPipe telemetry transport reference remains in ${entry.name}; refusing to build."
                    }
                    check(!classText.contains("com/google/mediapipe/proto/MediaPipeLogging")) {
                        "MediaPipe telemetry proto reference remains in ${entry.name}; refusing to build."
                    }
                }
                input.closeEntry()
            }
        }

        val temporary = File(outputAar.parentFile, "${outputAar.name}.tmp")
        ZipFile(sourceAar).use { aar ->
            ZipOutputStream(temporary.outputStream().buffered()).use { output ->
                val entries = aar.entries()
                while (entries.hasMoreElements()) {
                    val entry = entries.nextElement()
                    output.putNextEntry(ZipEntry(entry.name))
                    if (entry.name == "classes.jar") {
                        output.write(patchedClasses)
                    } else if (!entry.isDirectory) {
                        aar.getInputStream(entry).use { it.copyTo(output) }
                    }
                    output.closeEntry()
                }
            }
        }
        if (outputAar.exists()) check(outputAar.delete()) { "Could not replace the previous patched MediaPipe AAR." }
        check(temporary.renameTo(outputAar)) { "Could not write the privacy-patched MediaPipe AAR." }
    }
}

android {
    namespace = "com.ascend.coach"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = applicationIdFromProperty
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    sourceSets.getByName("main").assets.srcDir("../../assets/models")

    if (releaseSigningConfigured) {
        signingConfigs {
            create("release") {
                storeFile = file(releaseStorePath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            // No debug-key fallback: a release artifact is not produced unless the approved
            // production signing configuration is supplied through secure local properties.
            signingConfig = if (releaseSigningConfigured) signingConfigs.getByName("release") else null
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    mediaPipeCoreUpstream("com.google.mediapipe:tasks-core:1.2.2")
    mediaPipeVisionUpstream("com.google.mediapipe:tasks-vision:1.2.2")
    implementation(files(patchedMediaPipeCoreFile).builtBy(patchMediaPipeTelemetry))
    implementation("com.google.mediapipe:tasks-vision:1.2.2") {
        exclude(group = "com.google.mediapipe", module = "tasks-core")
    }
    // Direct non-telemetry tasks-core dependencies from the pinned upstream POM.
    implementation("com.google.flogger:flogger:0.6")
    implementation("com.google.flogger:flogger-system-backend:0.6")
    implementation("com.google.protobuf:protobuf-javalite:4.26.1")
    implementation("androidx.exifinterface:exifinterface:1.4.2")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    testImplementation("junit:junit:4.13.2")
}

tasks.named("preBuild").configure {
    dependsOn(patchMediaPipeTelemetry)
}
