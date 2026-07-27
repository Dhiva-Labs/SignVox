import 'dart:math' as math;
import 'dart:typed_data';

import 'landmark_frame.dart';

/// Per-hand normalization (PLAN.md §5.2): translate to wrist-relative
/// coordinates, scale by the wrist→middle-MCP distance (so hand size is
/// invariant to distance from the camera), and canonicalize handedness by
/// mirroring a left hand's x into right-hand space. This is the shared
/// feature space LetterEngine and DtwEngine both consume — get it wrong here
/// and every downstream recognizer inherits the mistake.
///
/// Pass [out] (length 63) to reuse a buffer — this runs on every camera frame,
/// and per-frame allocation is what PLAN_V2_RECOGNITION.md R5 exists to remove.
Float32List normalizeHand(HandLandmarks hand, {Float32List? out}) {
  final wristX = hand.x(0), wristY = hand.y(0), wristZ = hand.z(0);
  final scale = _handScale(hand);
  final mirror = hand.isLeft ? -1.0 : 1.0;

  final result = out ?? Float32List(63);
  for (var i = 0; i < 21; i++) {
    result[i * 3] = (hand.x(i) - wristX) / scale * mirror;
    result[i * 3 + 1] = (hand.y(i) - wristY) / scale;
    result[i * 3 + 2] = (hand.z(i) - wristZ) / scale;
  }
  return result;
}

/// Two-hand feature vector for Signs mode (PLAN.md §5.2): the dominant hand's
/// normalized 63, the other hand's normalized 63 (zeros if absent), an
/// other-hand-present flag, and the inter-wrist offset normalized by the
/// dominant hand's own scale. 63+63+1+2 = 129 floats.
///
/// [dominantIsLeft] reflects the user's left-handed-mode setting, not
/// MediaPipe's raw label — the caller decides which physical hand leads.
/// If the dominant hand isn't tracked this frame, the whole vector is zeros:
/// there's nothing meaningful to recognize without the signing hand, even if
/// the other hand happens to be visible.
Float32List buildTwoHandVector(
  List<HandLandmarks> hands, {
  required bool dominantIsLeft,
  Float32List? out,
}) {
  final result = out ?? Float32List(129);
  if (out != null) result.fillRange(0, result.length, 0.0);
  final dominant = _findHand(hands, dominantIsLeft);
  if (dominant == null) return result;

  normalizeHand(dominant, out: _scratchA);
  result.setRange(0, 63, _scratchA);

  final other = _findHand(hands, !dominantIsLeft);
  if (other != null) {
    normalizeHand(other, out: _scratchB);
    result.setRange(63, 126, _scratchB);
    result[126] = 1.0;
    final scale = _handScale(dominant);
    result[127] = (other.x(0) - dominant.x(0)) / scale;
    result[128] = (other.y(0) - dominant.y(0)) / scale;
  }
  return result;
}

/// Per-hand scratch buffers for [buildTwoHandVector]. Safe as library
/// singletons: the recognition spine is single-threaded per isolate and neither
/// function yields, so no two calls can interleave.
final Float32List _scratchA = Float32List(63);
final Float32List _scratchB = Float32List(63);

double _handScale(HandLandmarks hand) {
  final dx = hand.x(9) - hand.x(0);
  final dy = hand.y(9) - hand.y(0);
  final dz = hand.z(9) - hand.z(0);
  final scale = math.sqrt(dx * dx + dy * dy + dz * dz);
  return scale > 1e-6 ? scale : 1.0;
}

HandLandmarks? _findHand(List<HandLandmarks> hands, bool isLeft) {
  for (final h in hands) {
    if (h.isLeft == isLeft) return h;
  }
  return null;
}
