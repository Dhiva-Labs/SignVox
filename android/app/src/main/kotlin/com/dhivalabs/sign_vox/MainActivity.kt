package com.dhivalabs.sign_vox

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.speech.SpeechRecognizer
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import com.dhivalabs.sign_vox.vision.CameraEngine
import com.dhivalabs.sign_vox.vision.LandmarkerEngine
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the two platform channels described in PLAN.md §3: `signvox/camera` (a
 * MethodChannel to init/start/stop the pipeline) and `signvox/landmarks` (an
 * EventChannel streaming per-frame hand landmarks). All vision work happens here in
 * Kotlin; only landmark data crosses into Dart.
 *
 * FlutterActivity extends plain Activity, not ComponentActivity, so it has no
 * LifecycleOwner of its own — CameraX's bindToLifecycle needs one, hence the manual
 * LifecycleRegistry below.
 */
class MainActivity : FlutterActivity(), LifecycleOwner {

    private val lifecycleRegistry = LifecycleRegistry(this)
    override val lifecycle: Lifecycle
        get() = lifecycleRegistry

    private var cameraEngine: CameraEngine? = null
    private var landmarkerEngine: LandmarkerEngine? = null
    private var landmarksSink: EventChannel.EventSink? = null
    private var thermalListener: PowerManager.OnThermalStatusChangedListener? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        lifecycleRegistry.currentState = Lifecycle.State.CREATED
    }

    override fun onStart() {
        super.onStart()
        lifecycleRegistry.currentState = Lifecycle.State.STARTED
    }

    override fun onResume() {
        super.onResume()
        lifecycleRegistry.currentState = Lifecycle.State.RESUMED
    }

    override fun onPause() {
        lifecycleRegistry.currentState = Lifecycle.State.STARTED
        super.onPause()
    }

    override fun onStop() {
        lifecycleRegistry.currentState = Lifecycle.State.CREATED
        super.onStop()
    }

    override fun onDestroy() {
        lifecycleRegistry.currentState = Lifecycle.State.DESTROYED
        cameraEngine?.dispose()
        landmarkerEngine?.close()
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        landmarkerEngine = LandmarkerEngine(
            context = applicationContext,
            onResult = { result, inferenceMs -> emitLandmarks(result, inferenceMs) },
            onError = { message -> android.util.Log.e(TAG, "Landmarker error: $message") },
        )

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, LANDMARKS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    landmarksSink = events
                }

                override fun onCancel(arguments: Any?) {
                    landmarksSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CAMERA_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "init" -> handleInit(flutterEngine, result)
                    "start" -> result.success(null)
                    "stop" -> result.success(null)
                    "dispose" -> handleDispose(result)
                    "setAnalysisFps" -> {
                        val fps = call.argument<Int>("fps") ?: 30
                        cameraEngine?.setTargetFps(fps)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // PLAN.md §6.5: reply-mode STT must never silently fall back to a
        // network-backed recognizer. `speech_to_text`'s own `onDevice` flag
        // does exactly that when on-device recognition isn't supported
        // (confirmed by reading its Kotlin source: it falls through to
        // `createSpeechRecognizer`, which is Google-cloud-eligible, and that
        // call is proxied through a separate system process with its own
        // INTERNET permission — this app having none does not block it).
        // `SttService` calls this channel first and never starts a listening
        // session at all if it returns false, so that fallback path is never
        // reached in practice.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isOnDeviceAvailable" -> result.success(isOnDeviceSttAvailable())
                    else -> result.notImplemented()
                }
            }

        // PLAN.md §10 P7 adaptive FPS: streams PowerManager's thermal status
        // (Int, 0=NONE..6=SHUTDOWN) so Dart can lower setAnalysisFps under
        // sustained load. API 29+ only (older devices just never emit here —
        // Dart's default FPS stands, which is the correct fallback anyway).
        // Emulators typically report a fixed THERMAL_STATUS_NONE forever, so
        // this needs a real device to verify it actually reacts to heat.
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, THERMAL_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
                    val listener = PowerManager.OnThermalStatusChangedListener { status ->
                        mainHandler.post { events.success(status) }
                    }
                    thermalListener = listener
                    powerManager()?.addThermalStatusListener(mainExecutor, listener)
                }

                override fun onCancel(arguments: Any?) {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
                    thermalListener?.let { powerManager()?.removeThermalStatusListener(it) }
                    thermalListener = null
                }
            })
    }

    private fun powerManager(): PowerManager? = getSystemService(Context.POWER_SERVICE) as? PowerManager

    private fun isOnDeviceSttAvailable(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return false
        return SpeechRecognizer.isOnDeviceRecognitionAvailable(applicationContext)
    }

    private fun handleInit(flutterEngine: FlutterEngine, result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
            != PackageManager.PERMISSION_GRANTED
        ) {
            result.error("PERMISSION_DENIED", "Camera permission not granted", null)
            return
        }

        val landmarker = landmarkerEngine
            ?: return result.error("NOT_READY", "Landmarker not initialized", null)
        landmarker.setup()

        val engine = CameraEngine(
            context = applicationContext,
            lifecycleOwner = this,
            textureRegistry = flutterEngine.renderer,
            landmarker = landmarker,
        )
        cameraEngine = engine
        engine.init(
            onReady = { textureId, width, height, rotationDegrees ->
                mainHandler.post {
                    result.success(
                        mapOf(
                            "textureId" to textureId,
                            "previewW" to width,
                            "previewH" to height,
                            // Additive beyond PLAN.md §3's base contract: a raw Surface
                            // (not PreviewView) isn't auto-rotated, so Dart needs this to
                            // display the buffer upright.
                            "rotationDegrees" to rotationDegrees,
                        )
                    )
                }
            },
            onFailure = { message ->
                mainHandler.post { result.error("CAMERA_INIT_FAILED", message, null) }
            },
        )
    }

    private fun handleDispose(result: MethodChannel.Result) {
        cameraEngine?.dispose()
        cameraEngine = null
        landmarkerEngine?.close()
        result.success(null)
    }

    private fun emitLandmarks(result: HandLandmarkerResult, inferenceMs: Long) {
        val payload = toPayload(result, inferenceMs)
        mainHandler.post { landmarksSink?.success(payload) }
    }

    private fun toPayload(result: HandLandmarkerResult, inferenceMs: Long): Map<String, Any> {
        val handsOut = ArrayList<Map<String, Any>>(result.landmarks().size)
        val landmarksList = result.landmarks()
        val handednessList = result.handedness()
        for (i in landmarksList.indices) {
            val hand: List<NormalizedLandmark> = landmarksList[i]
            val floats = FloatArray(hand.size * 3)
            for (j in hand.indices) {
                floats[j * 3] = hand[j].x()
                floats[j * 3 + 1] = hand[j].y()
                floats[j * 3 + 2] = hand[j].z()
            }
            val topCategory = handednessList.getOrNull(i)?.getOrNull(0)
            // MediaPipe's handedness assumes a mirrored (selfie-style) input image; our
            // bitmap is already mirrored (CameraEngine), so the raw label matches the
            // user's true hand and needs no further swap.
            val handIndex = if (topCategory?.categoryName() == "Left") 1 else 0
            val score = topCategory?.score()?.toDouble() ?: 0.0
            handsOut.add(mapOf("hd" to handIndex, "score" to score, "lm" to floats))
        }
        return mapOf(
            "t" to result.timestampMs(),
            "infMs" to inferenceMs.toDouble(),
            "hands" to handsOut,
        )
    }

    companion object {
        private const val TAG = "SignVox"
        private const val CAMERA_CHANNEL = "signvox/camera"
        private const val LANDMARKS_CHANNEL = "signvox/landmarks"
        private const val STT_CHANNEL = "signvox/stt"
        private const val THERMAL_CHANNEL = "signvox/thermal"
    }
}
