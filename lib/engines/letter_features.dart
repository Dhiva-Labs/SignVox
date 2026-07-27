import 'dart:math' as math;
import 'dart:typed_data';

/// Feature extraction for the Spell-mode letter model — the Dart half of a
/// train/serve pair (PLAN_V2_RECOGNITION.md R-5).
///
/// The Python counterpart is `tools/letter_features.py`. `tools/make_fixtures.py`
/// writes `test/fixtures/letter_features_v2.json` from that module and
/// `test/letter_features_test.dart` asserts this file reproduces it within 1e-4.
/// Silent train/serve skew is the classic way a landmark model scores well
/// offline and fails on device, so treat those fixtures as load-bearing: change
/// the maths on one side and the other side's test must be regenerated and
/// re-run, not edited to match.
///
/// Feature layout (v2), [featureDimV2] dims, in this exact order:
///
/// ```
///     0.. 62  normalized 63 (wrist-relative, scale-normalized, handedness-
///             canonicalized) with z damped x0.5 — MediaPipe's z is noisy, and
///             every later block is computed from this damped copy so the whole
///             vector has one consistent representation.
///    63.. 64  sin, cos of the in-plane angle of wrist->middle-MCP
///    65.. 67  palm-normal unit vector, (indexMCP-wrist) x (pinkyMCP-wrist)
///    68..109  rotation-canonicalized xy of all 21 points (wrist->middle-MCP
///             rotated onto +y) — pure shape, orientation removed
///   110..119  10 pairwise fingertip distances (tips 4,8,12,16,20)
///   120..124  5 fingertip->wrist distances
///   125..134  cos of the flexion angle at each finger's PIP and DIP joints
/// ```
///
/// Orientation is deliberately kept as *explicit separate features* (63..67)
/// alongside the rotation-canonicalized shape (68..109) rather than thrown
/// away: ASL distinguishes G/Q, K/P and H/U by global hand orientation, so a
/// fully rotation-invariant representation would make those pairs unlearnable.
const int featureDimV2 = 135;

const int _wrist = 0;
const int _indexMcp = 5;
const int _middleMcp = 9;
const int _pinkyMcp = 17;
const List<int> _fingertips = [4, 8, 12, 16, 20];

/// (previous, joint, next) triples for the two flexion angles per finger.
const List<List<int>> _curlJoints = [
  [1, 2, 3], [2, 3, 4], // thumb MCP, IP
  [5, 6, 7], [6, 7, 8], // index PIP, DIP
  [9, 10, 11], [10, 11, 12], // middle PIP, DIP
  [13, 14, 15], [14, 15, 16], // ring PIP, DIP
  [17, 18, 19], [18, 19, 20], // pinky PIP, DIP
];

const double _zDamping = 0.5;
const double _eps = 1e-6;

/// Scratch buffer for the z-damped copy. Safe as a library-level singleton:
/// the recognition spine is single-threaded per isolate and [featuresV2]
/// never yields, so no two calls can interleave. This exists because
/// [featuresV2] runs on every camera frame and per-frame allocation is the
/// thing R5 is trying to eliminate.
final Float32List _damped = Float32List(63);

/// Computes the v2 feature vector from the normalized 63 produced by
/// `normalizeHand`. Pass [out] (length [featureDimV2]) to reuse a buffer and
/// keep the hot path allocation-free.
Float32List featuresV2(Float32List normalized63, {Float32List? out}) {
  final f = out ?? Float32List(featureDimV2);
  final p = _damped;
  for (var i = 0; i < 21; i++) {
    p[i * 3] = normalized63[i * 3];
    p[i * 3 + 1] = normalized63[i * 3 + 1];
    p[i * 3 + 2] = normalized63[i * 3 + 2] * _zDamping;
  }

  for (var i = 0; i < 63; i++) {
    f[i] = p[i];
  }

  // --- orientation, explicit ------------------------------------------
  final vx = p[_middleMcp * 3] - p[_wrist * 3];
  final vy = p[_middleMcp * 3 + 1] - p[_wrist * 3 + 1];
  final vLen = math.sqrt(vx * vx + vy * vy);
  final double cosT, sinT;
  if (vLen > _eps) {
    cosT = vx / vLen;
    sinT = vy / vLen;
  } else {
    cosT = 1.0;
    sinT = 0.0;
  }
  f[63] = sinT;
  f[64] = cosT;

  final ax = p[_indexMcp * 3] - p[_wrist * 3];
  final ay = p[_indexMcp * 3 + 1] - p[_wrist * 3 + 1];
  final az = p[_indexMcp * 3 + 2] - p[_wrist * 3 + 2];
  final bx = p[_pinkyMcp * 3] - p[_wrist * 3];
  final by = p[_pinkyMcp * 3 + 1] - p[_wrist * 3 + 1];
  final bz = p[_pinkyMcp * 3 + 2] - p[_wrist * 3 + 2];
  var nx = ay * bz - az * by;
  var ny = az * bx - ax * bz;
  var nz = ax * by - ay * bx;
  final nLen = math.sqrt(nx * nx + ny * ny + nz * nz);
  if (nLen > _eps) {
    nx /= nLen;
    ny /= nLen;
    nz /= nLen;
  } else {
    nx = 0.0;
    ny = 0.0;
    nz = 0.0;
  }
  f[65] = nx;
  f[66] = ny;
  f[67] = nz;

  // --- rotation-canonicalized shape (wrist->middle-MCP onto +y) --------
  // Rotating by -phi where cos(phi)=vy/|v|, sin(phi)=vx/|v| maps v to (0,|v|).
  final double c, s;
  if (vLen > _eps) {
    c = vy / vLen;
    s = vx / vLen;
  } else {
    c = 1.0;
    s = 0.0;
  }
  final wx = p[_wrist * 3];
  final wy = p[_wrist * 3 + 1];
  for (var i = 0; i < 21; i++) {
    final x = p[i * 3] - wx;
    final y = p[i * 3 + 1] - wy;
    f[68 + i * 2] = x * c - y * s;
    f[69 + i * 2] = x * s + y * c;
  }

  // --- distances -------------------------------------------------------
  var idx = 110;
  for (var i = 0; i < _fingertips.length; i++) {
    for (var j = i + 1; j < _fingertips.length; j++) {
      f[idx++] = _distance(p, _fingertips[i], _fingertips[j]);
    }
  }
  for (var i = 0; i < _fingertips.length; i++) {
    f[idx++] = _distance(p, _fingertips[i], _wrist);
  }

  // --- curl angles -----------------------------------------------------
  for (final joint in _curlJoints) {
    final a = joint[0], b = joint[1], cj = joint[2];
    final ux = p[a * 3] - p[b * 3];
    final uy = p[a * 3 + 1] - p[b * 3 + 1];
    final uz = p[a * 3 + 2] - p[b * 3 + 2];
    final wx2 = p[cj * 3] - p[b * 3];
    final wy2 = p[cj * 3 + 1] - p[b * 3 + 1];
    final wz2 = p[cj * 3 + 2] - p[b * 3 + 2];
    final nu = math.sqrt(ux * ux + uy * uy + uz * uz);
    final nw = math.sqrt(wx2 * wx2 + wy2 * wy2 + wz2 * wz2);
    f[idx++] = (nu > _eps && nw > _eps)
        ? (ux * wx2 + uy * wy2 + uz * wz2) / (nu * nw)
        : 0.0;
  }

  assert(idx == featureDimV2);
  return f;
}

double _distance(Float32List p, int a, int b) {
  final dx = p[a * 3] - p[b * 3];
  final dy = p[a * 3 + 1] - p[b * 3 + 1];
  final dz = p[a * 3 + 2] - p[b * 3 + 2];
  return math.sqrt(dx * dx + dy * dy + dz * dz);
}
