import 'dart:async';

import 'package:flutter/foundation.dart';

import 'landmark_frame.dart';
import 'normalize.dart';
import 'vision_channel.dart';
import 'vision_stats.dart';

/// Bridges [VisionChannel] to the UI: [frame] updates on every analyzed
/// camera frame (drives the overlay repaint directly via CustomPainter's
/// `repaint` listenable — no setState), while [stats] updates a few times a
/// second for the debug HUD.
///
/// One shared instance per app (see `providers.dart`), not one per screen —
/// Android's camera is exclusive, and Translate/Data Lab/Teach all want the
/// same hand-tracking pipeline, just doing different things with the
/// landmarks. [ensureStarted] is idempotent so any of them can call it
/// without double-initializing the camera.
class VisionController {
  VisionController(this._channel);

  final VisionChannel _channel;
  StreamSubscription<LandmarkFrame>? _sub;
  Future<CameraInit>? _startFuture;

  final ValueNotifier<LandmarkFrame?> frame = ValueNotifier(null);
  final ValueNotifier<VisionStats> stats = ValueNotifier(VisionStats.zero);

  int _windowFrameCount = 0;
  DateTime _windowStart = DateTime.now();
  static const _statsWindow = Duration(milliseconds: 250);

  Future<CameraInit> ensureStarted() => _startFuture ??= _start();

  Future<void> setAnalysisFps(int fps) => _channel.setAnalysisFps(fps);

  Future<CameraInit> _start() async {
    final init = await _channel.init();
    _windowStart = DateTime.now();
    _sub = _channel.landmarks.listen(_onFrame);
    return init;
  }

  void _onFrame(LandmarkFrame f) {
    frame.value = f;

    _windowFrameCount++;
    final elapsed = DateTime.now().difference(_windowStart);
    if (elapsed >= _statsWindow) {
      final fps =
          _windowFrameCount /
          elapsed.inMicroseconds *
          Duration.microsecondsPerSecond;
      final firstHand = f.hands.isEmpty ? null : f.hands.first;
      stats.value = VisionStats(
        fps: fps,
        lastInferenceMs: f.inferenceMs,
        handCount: f.hands.length,
        normalizedIndexTipY: firstHand == null
            ? null
            : normalizeHand(firstHand)[8 * 3 + 1],
      );
      _windowFrameCount = 0;
      _windowStart = DateTime.now();
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _channel.dispose();
    frame.dispose();
    stats.dispose();
  }
}
