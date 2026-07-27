package com.dhivalabs.sign_vox.vision

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Matrix
import android.os.Handler
import android.os.Looper
import android.util.Size
import android.view.Surface
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import io.flutter.view.TextureRegistry
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

/**
 * Drives CameraX's front-camera preview straight into a Flutter Texture, and feeds a
 * throttleable analysis stream into [LandmarkerEngine]. Camera frames never cross the
 * platform channel — only committed landmarks do.
 */
class CameraEngine(
    private val context: Context,
    private val lifecycleOwner: LifecycleOwner,
    private val textureRegistry: TextureRegistry,
    private val landmarker: LandmarkerEngine,
) {
    private var cameraProvider: ProcessCameraProvider? = null
    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private val analysisExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    // Thermal throttle hook: process every Nth analysis frame (1 = every frame).
    private val frameDivider = AtomicInteger(1)
    private var frameCounter = 0

    // Reused across frames to avoid per-frame allocation; safe because LandmarkerEngine
    // guarantees at most one in-flight detectAsync call (see isBusy), so these buffers
    // are never written to while MediaPipe is still reading the previous frame from them.
    private var stagingBitmap: Bitmap? = null
    private var outputBitmap: Bitmap? = null
    private var outputCanvas: Canvas? = null

    fun init(
        onReady: (textureId: Long, width: Int, height: Int, rotationDegrees: Int) -> Unit,
        onFailure: (String) -> Unit,
    ) {
        val entry = textureRegistry.createSurfaceTexture()
        textureEntry = entry
        val providerFuture = ProcessCameraProvider.getInstance(context)
        providerFuture.addListener({
            try {
                val provider = providerFuture.get()
                cameraProvider = provider
                bindUseCases(provider, entry, onReady, onFailure)
            } catch (t: Throwable) {
                onFailure(t.message ?: "Failed to obtain CameraProvider")
            }
        }, ContextCompat.getMainExecutor(context))
    }

    @SuppressLint("UnsafeOptInUsageError")
    private fun bindUseCases(
        provider: ProcessCameraProvider,
        entry: TextureRegistry.SurfaceTextureEntry,
        onReady: (Long, Int, Int, Int) -> Unit,
        onFailure: (String) -> Unit,
    ) {
        var reported = false
        val preview = Preview.Builder().build()
        preview.setSurfaceProvider { request ->
            val surfaceTexture = entry.surfaceTexture()
            surfaceTexture.setDefaultBufferSize(request.resolution.width, request.resolution.height)
            val surface = Surface(surfaceTexture)
            // A raw Surface (unlike PreviewView) isn't auto-rotated by CameraX, so the
            // buffer stays in sensor (landscape) orientation; TransformationInfo is the
            // supported way to learn the clockwise rotation the consumer must apply.
            request.setTransformationInfoListener(ContextCompat.getMainExecutor(context)) { info ->
                if (!reported) {
                    reported = true
                    onReady(entry.id(), request.resolution.width, request.resolution.height, info.rotationDegrees)
                }
            }
            request.provideSurface(surface, analysisExecutor) { }
        }

        val analysis = ImageAnalysis.Builder()
            .setTargetResolution(Size(640, 480))
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
            .build()
        analysis.setAnalyzer(analysisExecutor) { imageProxy -> onFrame(imageProxy) }

        provider.unbindAll()
        try {
            provider.bindToLifecycle(
                lifecycleOwner,
                CameraSelector.DEFAULT_FRONT_CAMERA,
                preview,
                analysis,
            )
        } catch (t: Throwable) {
            onFailure(t.message ?: "bindToLifecycle failed")
        }
    }

    private fun onFrame(imageProxy: ImageProxy) {
        frameCounter++
        val shouldSkip = frameCounter % frameDivider.get() != 0
        if (shouldSkip || !landmarker.isReady || landmarker.isBusy) {
            imageProxy.close()
            return
        }
        try {
            val bitmap = imageProxyToUprightMirroredBitmap(imageProxy)
            landmarker.detect(bitmap)
        } catch (t: Throwable) {
            // A single malformed frame shouldn't kill the analyzer loop.
        } finally {
            imageProxy.close()
        }
    }

    /**
     * Converts the analysis buffer to an upright, horizontally-mirrored bitmap so the
     * landmark coordinates MediaPipe emits land in the same visual space as the
     * mirrored preview shown to the user (PLAN.md §3/§5.2).
     */
    private fun imageProxyToUprightMirroredBitmap(imageProxy: ImageProxy): Bitmap {
        val plane = imageProxy.planes[0]
        val pixelStride = plane.pixelStride
        val rowStride = plane.rowStride
        val width = imageProxy.width
        val height = imageProxy.height
        val strideWidth = rowStride / pixelStride

        val source: Bitmap
        if (strideWidth == width) {
            var staging = stagingBitmap
            if (staging == null || staging.width != width || staging.height != height) {
                staging = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                stagingBitmap = staging
            }
            staging.copyPixelsFromBuffer(plane.buffer)
            source = staging
        } else {
            // Row padding present — crop before rotating so garbage columns don't leak in.
            val padded = Bitmap.createBitmap(strideWidth, height, Bitmap.Config.ARGB_8888)
            padded.copyPixelsFromBuffer(plane.buffer)
            source = Bitmap.createBitmap(padded, 0, 0, width, height)
            padded.recycle()
        }

        val rotation = imageProxy.imageInfo.rotationDegrees
        val rotatedIsPortrait = rotation == 90 || rotation == 270
        val outW = if (rotatedIsPortrait) height else width
        val outH = if (rotatedIsPortrait) width else height

        var out = outputBitmap
        if (out == null || out.width != outW || out.height != outH) {
            out = Bitmap.createBitmap(outW, outH, Bitmap.Config.ARGB_8888)
            outputBitmap = out
            outputCanvas = Canvas(out)
        }
        val canvas = outputCanvas!!
        val matrix = Matrix()
        matrix.postTranslate(-width / 2f, -height / 2f)
        matrix.postRotate(rotation.toFloat())
        matrix.postScale(-1f, 1f)
        matrix.postTranslate(outW / 2f, outH / 2f)
        canvas.drawBitmap(source, matrix, null)
        return out
    }

    /**
     * Frame-skipping only quantizes to integer divisions of the sensor's actual capture
     * rate (~30fps), so requests are rounded to the nearest achievable step rather than
     * hit exactly — full/~15fps/~10fps for a 30fps sensor.
     */
    fun setTargetFps(fps: Int) {
        frameDivider.set(
            when {
                fps >= 26 -> 1
                fps >= 13 -> 2
                else -> 3
            }
        )
    }

    fun dispose() {
        cameraProvider?.unbindAll()
        cameraProvider = null
        textureEntry?.release()
        textureEntry = null
        stagingBitmap?.recycle()
        stagingBitmap = null
        outputBitmap?.recycle()
        outputBitmap = null
        outputCanvas = null
        analysisExecutor.shutdown()
    }
}
