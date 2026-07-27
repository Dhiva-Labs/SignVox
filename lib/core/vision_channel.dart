import 'package:flutter/services.dart';

import 'landmark_frame.dart';

/// Result of [VisionChannel.init]: the Flutter Texture id to render the
/// camera preview with, its pixel dimensions, and the clockwise rotation
/// needed to display it upright (the raw Surface isn't auto-rotated the way
/// PreviewView would be — see PLAN.md §3).
class CameraInit {
  const CameraInit({
    required this.textureId,
    required this.previewWidth,
    required this.previewHeight,
    required this.rotationDegrees,
  });

  final int textureId;
  final int previewWidth;
  final int previewHeight;
  final int rotationDegrees;

  bool get isSwapped => rotationDegrees == 90 || rotationDegrees == 270;
  int get displayWidth => isSwapped ? previewHeight : previewWidth;
  int get displayHeight => isSwapped ? previewWidth : previewHeight;
}

/// Dart-side wrapper for the native vision pipeline (PLAN.md §3): a
/// MethodChannel to control the camera/landmarker lifecycle, and an
/// EventChannel streaming per-frame hand landmarks. All camera frames and
/// ML inference stay on the Kotlin side — only landmark data crosses here.
class VisionChannel {
  static const MethodChannel _method = MethodChannel('signvox/camera');
  static const EventChannel _events = EventChannel('signvox/landmarks');

  Stream<LandmarkFrame>? _landmarks;

  Future<CameraInit> init() async {
    final result = await _method.invokeMapMethod<String, Object?>('init');
    final map = result!;
    return CameraInit(
      textureId: map['textureId'] as int,
      previewWidth: map['previewW'] as int,
      previewHeight: map['previewH'] as int,
      rotationDegrees: map['rotationDegrees'] as int,
    );
  }

  Future<void> start() => _method.invokeMethod('start');

  Future<void> stop() => _method.invokeMethod('stop');

  Future<void> dispose() => _method.invokeMethod('dispose');

  Future<void> setAnalysisFps(int fps) =>
      _method.invokeMethod('setAnalysisFps', {'fps': fps});

  /// Broadcast stream of landmark frames; safe to listen to more than once
  /// (e.g. from both the overlay painter and the recognition engines).
  Stream<LandmarkFrame> get landmarks {
    return _landmarks ??= _events.receiveBroadcastStream().map(
      (event) => LandmarkFrame.fromMap(event as Map<Object?, Object?>),
    );
  }
}
