package com.dhivalabs.sign_vox.vision

import android.content.Context
import android.graphics.Bitmap
import android.os.SystemClock
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult

/**
 * Wraps MediaPipe's HandLandmarker in LIVE_STREAM mode. Tries the GPU delegate first
 * and falls back to CPU, since GPU delegate init fails on some emulator/device drivers.
 */
class LandmarkerEngine(
    private val context: Context,
    private val onResult: (result: HandLandmarkerResult, inferenceMs: Long) -> Unit,
    private val onError: (String) -> Unit,
) {
    private var handLandmarker: HandLandmarker? = null

    var usingGpu: Boolean = false
        private set

    val isReady: Boolean
        get() = handLandmarker != null

    // LIVE_STREAM mode allows only one outstanding detectAsync call at a time; callers
    // must check this before feeding another frame.
    @Volatile
    var isBusy: Boolean = false
        private set

    fun setup() {
        handLandmarker = tryCreate(Delegate.GPU)?.also { usingGpu = true }
            ?: tryCreate(Delegate.CPU)?.also { usingGpu = false }
        if (handLandmarker == null) {
            onError("Failed to initialize HandLandmarker on both GPU and CPU delegates")
        }
    }

    private fun tryCreate(delegate: Delegate): HandLandmarker? = try {
        val baseOptions = BaseOptions.builder()
            // Flutter nests Dart-declared pubspec assets under flutter_assets/ inside the
            // APK's own assets/ folder — the raw pubspec path alone isn't readable here.
            .setModelAssetPath("flutter_assets/assets/models/hand_landmarker.task")
            .setDelegate(delegate)
            .build()
        val options = HandLandmarker.HandLandmarkerOptions.builder()
            .setBaseOptions(baseOptions)
            .setRunningMode(RunningMode.LIVE_STREAM)
            .setNumHands(2)
            .setMinHandDetectionConfidence(0.5f)
            .setMinHandPresenceConfidence(0.5f)
            .setMinTrackingConfidence(0.5f)
            .setResultListener { result, _ -> handleResult(result) }
            .setErrorListener { e -> onError(e.message ?: "HandLandmarker error") }
            .build()
        HandLandmarker.createFromOptions(context, options)
    } catch (t: Throwable) {
        android.util.Log.e("SignVox", "tryCreate($delegate) failed", t)
        null
    }

    private fun handleResult(result: HandLandmarkerResult) {
        val inferenceMs = SystemClock.uptimeMillis() - result.timestampMs()
        isBusy = false
        onResult(result, inferenceMs)
    }

    /** Feed one upright, mirrored ARGB bitmap. Caller must check [isBusy]/[isReady] first. */
    fun detect(bitmap: Bitmap) {
        val landmarker = handLandmarker ?: return
        isBusy = true
        val mpImage = BitmapImageBuilder(bitmap).build()
        landmarker.detectAsync(mpImage, SystemClock.uptimeMillis())
    }

    fun close() {
        handLandmarker?.close()
        handLandmarker = null
        isBusy = false
    }
}
