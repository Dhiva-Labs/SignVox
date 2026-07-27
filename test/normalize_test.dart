import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sign_vox/core/landmark_frame.dart';
import 'package:sign_vox/core/normalize.dart';

// A fixed, arbitrary (not anatomically real) set of 21 landmark offsets
// relative to the wrist, used to build synthetic hands for invariance
// checks. landmark 9 (middle MCP) sits at (0, -0.1, 0) so the wrist->MCP
// scale reference is a known 0.1 before any translation/scale is applied.
const _offsets = [
  [0.0, 0.0, 0.0], // 0 wrist
  [0.02, -0.03, 0.01], [0.03, -0.06, 0.01], [0.04, -0.08, 0.02], [0.05, -0.10, 0.02], // thumb
  [0.03, -0.08, 0.0], [0.03, -0.12, 0.0], [0.03, -0.15, 0.0], [0.03, -0.18, 0.0], // index
  [0.0, -0.10, 0.0], [0.0, -0.15, 0.0], [0.0, -0.19, 0.0], [0.0, -0.22, 0.0], // middle
  [-0.03, -0.09, 0.0], [-0.03, -0.14, 0.0], [-0.03, -0.17, 0.0], [-0.03, -0.20, 0.0], // ring
  [-0.06, -0.07, 0.0], [-0.06, -0.11, 0.0], [-0.06, -0.14, 0.0], [-0.06, -0.16, 0.0], // pinky
];

Float32List _rawLandmarks({
  required List<double> wrist,
  double scaleFactor = 1.0,
  bool mirrorX = false,
}) {
  final out = Float32List(63);
  for (var i = 0; i < 21; i++) {
    final signX = mirrorX ? -1.0 : 1.0;
    out[i * 3] = wrist[0] + _offsets[i][0] * scaleFactor * signX;
    out[i * 3 + 1] = wrist[1] + _offsets[i][1] * scaleFactor;
    out[i * 3 + 2] = wrist[2] + _offsets[i][2] * scaleFactor;
  }
  return out;
}

void _expectClose(Float32List a, Float32List b, {double epsilon = 1e-4}) {
  expect(a.length, b.length);
  for (var i = 0; i < a.length; i++) {
    expect(a[i], closeTo(b[i], epsilon), reason: 'differs at index $i');
  }
}

void main() {
  group('normalizeHand', () {
    test('is invariant to translation', () {
      final near = HandLandmarks(
        isLeft: false,
        score: 0.9,
        landmarks: _rawLandmarks(wrist: [0.5, 0.5, 0.0]),
      );
      final far = HandLandmarks(
        isLeft: false,
        score: 0.9,
        landmarks: _rawLandmarks(wrist: [0.2, 0.8, 0.0]),
      );
      _expectClose(normalizeHand(near), normalizeHand(far));
    });

    test('is invariant to scale (distance from camera)', () {
      final normalSize = HandLandmarks(
        isLeft: false,
        score: 0.9,
        landmarks: _rawLandmarks(wrist: [0.5, 0.5, 0.0]),
      );
      final doubleSize = HandLandmarks(
        isLeft: false,
        score: 0.9,
        landmarks: _rawLandmarks(wrist: [0.5, 0.5, 0.0], scaleFactor: 2.0),
      );
      _expectClose(normalizeHand(normalSize), normalizeHand(doubleSize));
    });

    test('mirrors a left hand into right-hand space', () {
      final right = HandLandmarks(
        isLeft: false,
        score: 0.9,
        landmarks: _rawLandmarks(wrist: [0.5, 0.5, 0.0]),
      );
      final left = HandLandmarks(
        isLeft: true,
        score: 0.9,
        landmarks: _rawLandmarks(wrist: [0.5, 0.5, 0.0], mirrorX: true),
      );
      _expectClose(normalizeHand(right), normalizeHand(left));
    });

    test('wrist and middle-MCP land at the expected canonical positions', () {
      final hand = HandLandmarks(
        isLeft: false,
        score: 0.9,
        landmarks: _rawLandmarks(wrist: [0.3, 0.7, 0.1]),
      );
      final normalized = normalizeHand(hand);
      // Wrist (landmark 0) is the translation origin.
      expect(normalized[0], closeTo(0.0, 1e-4));
      expect(normalized[1], closeTo(0.0, 1e-4));
      // Middle MCP (landmark 9) is exactly one scale-unit away, straight up.
      expect(normalized[9 * 3], closeTo(0.0, 1e-4));
      expect(normalized[9 * 3 + 1], closeTo(-1.0, 1e-4));
    });
  });

  group('buildTwoHandVector', () {
    test('zero-fills the other-hand slot and flag when only one hand is tracked', () {
      final dominant = HandLandmarks(
        isLeft: false,
        score: 0.9,
        landmarks: _rawLandmarks(wrist: [0.5, 0.5, 0.0]),
      );
      final vec = buildTwoHandVector([dominant], dominantIsLeft: false);
      expect(vec.length, 129);
      expect(vec.sublist(63, 126).every((v) => v == 0.0), isTrue);
      expect(vec[126], 0.0);
      expect(vec[127], 0.0);
      expect(vec[128], 0.0);
      // Dominant hand's own normalization still lands in the first 63.
      _expectClose(vec.sublist(0, 63), normalizeHand(dominant));
    });

    test('is all-zero when the dominant hand is not tracked, even if the other hand is', () {
      final onlyOther = HandLandmarks(
        isLeft: true,
        score: 0.9,
        landmarks: _rawLandmarks(wrist: [0.5, 0.5, 0.0]),
      );
      final vec = buildTwoHandVector([onlyOther], dominantIsLeft: false);
      expect(vec.every((v) => v == 0.0), isTrue);
    });

    test('sets the presence flag and inter-wrist offset when both hands are tracked', () {
      final dominant = HandLandmarks(
        isLeft: false,
        score: 0.9,
        landmarks: _rawLandmarks(wrist: [0.5, 0.5, 0.0]),
      );
      // Other hand's wrist sits one dominant-scale-unit to the right.
      final other = HandLandmarks(
        isLeft: true,
        score: 0.9,
        landmarks: _rawLandmarks(wrist: [0.6, 0.5, 0.0]),
      );
      final vec = buildTwoHandVector([dominant, other], dominantIsLeft: false);
      expect(vec[126], 1.0);
      expect(vec[127], closeTo(1.0, 1e-4));
      expect(vec[128], closeTo(0.0, 1e-4));
    });
  });
}
