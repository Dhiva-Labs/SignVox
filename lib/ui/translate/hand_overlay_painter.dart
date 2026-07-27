import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/landmark_frame.dart';

/// Draws the 21-point MediaPipe hand skeleton. Repaints are driven entirely
/// by the [frame] ValueNotifier passed as this painter's `repaint`
/// listenable — no setState anywhere on the hot path (PLAN.md §3/§11).
///
/// Styling is deliberately quiet — thin translucent white bones, small white
/// joints — so the overlay reads as an instrument, not a laser show. The only
/// color is on fingertips: accent blue for the right hand, mint for the left,
/// which preserves the handedness cue at a glance.
class HandOverlayPainter extends CustomPainter {
  HandOverlayPainter(this.frame) : super(repaint: frame);

  final ValueListenable<LandmarkFrame?> frame;

  // Standard MediaPipe hand landmark connections: thumb, index, middle,
  // ring, pinky, and the palm base back to the pinky's MCP.
  static const List<List<int>> _connections = [
    [0, 1],
    [1, 2],
    [2, 3],
    [3, 4],
    [0, 5],
    [5, 6],
    [6, 7],
    [7, 8],
    [5, 9],
    [9, 10],
    [10, 11],
    [11, 12],
    [9, 13],
    [13, 14],
    [14, 15],
    [15, 16],
    [13, 17],
    [17, 18],
    [18, 19],
    [19, 20],
    [0, 17],
  ];

  static const _rightTip = Color(0xFF0A84FF);
  static const _leftTip = Color(0xFF66D4CF);
  static const _fingertips = {4, 8, 12, 16, 20};

  @override
  void paint(Canvas canvas, Size size) {
    final current = frame.value;
    if (current == null) return;
    for (final hand in current.hands) {
      _paintHand(canvas, size, hand);
    }
  }

  void _paintHand(Canvas canvas, Size size, HandLandmarks hand) {
    final tipColor = hand.isLeft ? _leftTip : _rightTip;
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.72)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final jointPaint = Paint()..color = Colors.white.withValues(alpha: 0.9);
    final tipPaint = Paint()..color = tipColor;

    Offset point(int i) =>
        Offset(hand.x(i) * size.width, hand.y(i) * size.height);

    for (final connection in _connections) {
      canvas.drawLine(point(connection[0]), point(connection[1]), linePaint);
    }
    for (var i = 0; i < 21; i++) {
      canvas.drawCircle(
        point(i),
        _fingertips.contains(i) ? 3.5 : 2.5,
        _fingertips.contains(i) ? tipPaint : jointPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant HandOverlayPainter oldDelegate) =>
      oldDelegate.frame != frame;
}
