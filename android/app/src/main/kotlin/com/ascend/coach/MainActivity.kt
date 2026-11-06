package com.ascend.coach

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.exifinterface.media.ExifInterface
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.security.MessageDigest
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
  companion object {
    private const val FACE_CHANNEL = "ascend/face_analysis"
    private const val STORE_CHANNEL = "ascend/store"
    private const val MODEL_ASSET = "face_landmarker_v1.task"
    private const val MODEL_VERSION = "mediapipe-face-landmarker-float16-v1"
    private const val MODEL_SHA256 = "64184e229b263107bc2b804c6625db1341ff2bb731874b0bcc2fe6544e0bc9ff"
    private const val MAX_IMAGE_BYTES = 20L * 1024L * 1024L
    private const val MAX_FACES = 5
  }

  private val inferenceExecutor = Executors.newSingleThreadExecutor()
  private val mainHandler = Handler(Looper.getMainLooper())
  @Volatile private var faceLandmarker: FaceLandmarker? = null
  @Volatile private var modelReady = false
  @Volatile private var modelFailureCode: String? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FACE_CHANNEL)
      .setMethodCallHandler { call, result -> handleFaceCall(call, result) }
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STORE_CHANNEL)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "manageSubscriptions" -> openSubscriptionManagement(result)
          else -> result.notImplemented()
        }
      }
  }

  private fun handleFaceCall(call: MethodCall, result: MethodChannel.Result) {
    if (call.method != "analyzeImage") {
      result.notImplemented()
      return
    }
    val path = call.argument<String>("path")
    val expectedVersion = call.argument<String>("expectedModelVersion")
    if (path.isNullOrBlank() || expectedVersion != MODEL_VERSION) {
      result.error("UNSUPPORTED_IMAGE", "The image request or model version is unsupported.", null)
      return
    }
    inferenceExecutor.execute {
      try {
        val response = analyzeLocalFile(path)
        mainHandler.post { result.success(response) }
      } catch (error: NativeModelException) {
        mainHandler.post { result.error(error.code, error.message, null) }
      } catch (_: OutOfMemoryError) {
        mainHandler.post { result.error("INFERENCE_FAILED", "This device could not process the image with available memory.", null) }
      } catch (_: LinkageError) {
        mainHandler.post { result.error("MODEL_ASSET_MISSING", "The on-device MediaPipe runtime is unavailable on this build.", null) }
      } catch (_: Exception) {
        mainHandler.post { result.error("INFERENCE_FAILED", "On-device face analysis failed. Retake the photo or try another supported device.", null) }
      }
    }
  }

  private fun analyzeLocalFile(path: String): Map<String, Any> {
    ensureModelLoaded()
    val file = File(path).canonicalFile
    val cacheRoot = cacheDir.canonicalFile.path + File.separator
    val filesRoot = filesDir.canonicalFile.path + File.separator
    if (!file.isFile || !(file.path.startsWith(cacheRoot) || file.path.startsWith(filesRoot)) ||
      file.length() <= 0 || file.length() > MAX_IMAGE_BYTES) {
      throw NativeModelException("UNSUPPORTED_IMAGE", "The captured image is unavailable or outside the supported size limit.")
    }

    val bitmap = decodeUprightBitmap(file)
      ?: throw NativeModelException("UNSUPPORTED_IMAGE", "The captured image could not be decoded.")
    try {
      val input = BitmapImageBuilder(bitmap).build()
      val landmarker = faceLandmarker
        ?: throw NativeModelException("MODEL_ASSET_MISSING", "The on-device face model is unavailable.")
      val result = landmarker.detect(input)
      val faces = result.faceLandmarks().map { face ->
        face.map { landmark ->
          listOf(landmark.x().toDouble(), landmark.y().toDouble(), landmark.z().toDouble())
        }
      }
      return mapOf("modelVersion" to MODEL_VERSION, "faces" to faces)
    } finally {
      bitmap.recycle()
    }
  }

  @Synchronized
  private fun ensureModelLoaded() {
    if (modelReady) return
    modelFailureCode?.let { code ->
      throw NativeModelException(code, "The installed on-device face model could not be validated.")
    }
    val modelBytes = try {
      assets.open("face_landmarker_v1.task").use { it.readBytes() }
    } catch (_: Exception) {
      modelFailureCode = "MODEL_ASSET_MISSING"
      throw NativeModelException("MODEL_ASSET_MISSING", "The bundled on-device face model is missing.")
    }
    val digest = MessageDigest.getInstance("SHA-256").digest(modelBytes)
      .joinToString("") { byte -> "%02x".format(byte) }
    if (!digest.equals(MODEL_SHA256, ignoreCase = true)) {
      modelFailureCode = "MODEL_CHECKSUM_MISMATCH"
      throw NativeModelException("MODEL_CHECKSUM_MISMATCH", "The bundled on-device face model failed checksum validation.")
    }
    try {
      val options = FaceLandmarker.FaceLandmarkerOptions.builder()
        .setBaseOptions(BaseOptions.builder().setModelAssetPath(MODEL_ASSET).build())
        .setRunningMode(RunningMode.IMAGE)
        .setNumFaces(MAX_FACES)
        .setMinFaceDetectionConfidence(0.6f)
        .setMinFacePresenceConfidence(0.6f)
        .setMinTrackingConfidence(0.6f)
        .setOutputFaceBlendshapes(false)
        .setOutputFacialTransformationMatrixes(false)
        .build()
      faceLandmarker = FaceLandmarker.createFromOptions(applicationContext, options)
      modelReady = true
    } catch (_: LinkageError) {
      modelFailureCode = "MODEL_ASSET_MISSING"
      throw NativeModelException("MODEL_ASSET_MISSING", "The on-device MediaPipe runtime is unavailable on this build.")
    } catch (_: Exception) {
      modelFailureCode = "MODEL_ASSET_MISSING"
      throw NativeModelException("MODEL_ASSET_MISSING", "The bundled face model is incompatible with this device or MediaPipe runtime.")
    }
  }

  private fun decodeUprightBitmap(file: File): Bitmap? {
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeFile(file.path, bounds)
    if (bounds.outWidth < 100 || bounds.outHeight < 100) return null
    var sampleSize = 1
    while (bounds.outWidth / sampleSize > 2000 || bounds.outHeight / sampleSize > 2000) sampleSize *= 2
    val decoded = BitmapFactory.decodeFile(file.path, BitmapFactory.Options().apply {
      inSampleSize = sampleSize
      inPreferredConfig = Bitmap.Config.ARGB_8888
    }) ?: return null
    val orientation = try {
      FileInputStream(file).use { stream -> ExifInterface(stream).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL) }
    } catch (_: Exception) {
      ExifInterface.ORIENTATION_NORMAL
    }
    val transform = Matrix()
    when (orientation) {
      ExifInterface.ORIENTATION_ROTATE_90 -> transform.setRotate(90f)
      ExifInterface.ORIENTATION_ROTATE_180 -> transform.setRotate(180f)
      ExifInterface.ORIENTATION_ROTATE_270 -> transform.setRotate(270f)
      ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> transform.setScale(-1f, 1f)
      ExifInterface.ORIENTATION_FLIP_VERTICAL -> transform.setScale(1f, -1f)
      else -> return decoded
    }
    return try {
      Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, transform, true).also {
        if (it !== decoded) decoded.recycle()
      }
    } catch (_: Exception) {
      decoded
    }
  }

  private fun openSubscriptionManagement(result: MethodChannel.Result) {
    val uri = Uri.parse("https://play.google.com/store/account/subscriptions?package=$packageName")
    try {
      startActivity(Intent(Intent.ACTION_VIEW, uri))
      result.success(null)
    } catch (_: Exception) {
      result.error("STORE_UNAVAILABLE", "Google Play subscription settings could not be opened.", null)
    }
  }

  override fun onDestroy() {
    inferenceExecutor.execute {
      faceLandmarker?.close()
      faceLandmarker = null
    }
    inferenceExecutor.shutdown()
    super.onDestroy()
  }

  private class NativeModelException(val code: String, override val message: String) : Exception(message)
}
