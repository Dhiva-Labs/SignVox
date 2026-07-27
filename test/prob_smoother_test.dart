import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sign_vox/engines/prob_smoother.dart';

void main() {
  group('ProbSmoother', () {
    test('the first frame passes through unchanged', () {
      final s = ProbSmoother(alpha: 0.3);
      final out = s.add(Float32List.fromList([0.7, 0.2, 0.1]));
      expect(out[0], closeTo(0.7, 1e-6));
      expect(out[1], closeTo(0.2, 1e-6));
    });

    test('a single outlier frame moves the estimate by alpha, not all the way', () {
      // This is the whole point: v1.0 took the raw argmax, so one bad frame
      // flipped the top-1 label and reset the hold.
      final s = ProbSmoother(alpha: 0.3);
      s.add(Float32List.fromList([0.9, 0.1]));
      final out = s.add(Float32List.fromList([0.0, 1.0]));
      expect(out[0], closeTo(0.9 * 0.7, 1e-5));
      expect(out[1], closeTo(0.1 * 0.7 + 0.3, 1e-5));
      expect(out[0], greaterThan(out[1]), reason: 'one glitched frame must not flip the winner');
    });

    test('a genuinely changed distribution takes over within a few frames', () {
      final s = ProbSmoother(alpha: 0.3);
      s.add(Float32List.fromList([0.9, 0.1]));
      Float32List out = s.add(Float32List.fromList([0.0, 1.0]));
      for (var i = 0; i < 3; i++) {
        out = s.add(Float32List.fromList([0.0, 1.0]));
      }
      expect(out[1], greaterThan(out[0]), reason: 'a real change must still win quickly');
    });

    test('reset forgets everything — a hand-lost gap must not leak across', () {
      final s = ProbSmoother(alpha: 0.3);
      s.add(Float32List.fromList([0.9, 0.1]));
      s.reset();
      expect(s.isEmpty, isTrue);
      final out = s.add(Float32List.fromList([0.1, 0.9]));
      expect(out[1], closeTo(0.9, 1e-6));
    });

    test('reuses one buffer across frames (no per-frame allocation)', () {
      final s = ProbSmoother();
      final first = s.add(Float32List.fromList([0.5, 0.5]));
      final second = s.add(Float32List.fromList([0.5, 0.5]));
      expect(identical(first, second), isTrue);
    });
  });

  group('HandVelocityGate', () {
    Float32List vec(double v) => Float32List.fromList(List.filled(63, v));

    test('a still hand is never reported as transitioning', () {
      final gate = HandVelocityGate();
      gate.addFrame(vec(0.5));
      for (var i = 0; i < 40; i++) {
        expect(gate.addFrame(vec(0.5 + 0.0001 * (i % 2))), isFalse);
      }
    });

    test('a fast-moving hand is reported as transitioning', () {
      final gate = HandVelocityGate();
      for (var i = 0; i < 30; i++) {
        gate.addFrame(vec(0.5 + 0.0001 * (i % 2))); // settle the noise floor low
      }
      expect(gate.addFrame(vec(0.9)), isTrue);
    });

    test('the noise floor adapts, so a shaky hand still reaches "still"', () {
      final jittery = HandVelocityGate();
      // 0.02-per-dim jitter would trip a fixed threshold forever.
      for (var i = 0; i < 120; i++) {
        jittery.addFrame(vec(0.5 + 0.02 * (i % 2)));
      }
      expect(jittery.addFrame(vec(0.5 + 0.02)), isFalse,
          reason: 'the floor should have risen to treat this jitter as still');
    });

    test('reset clears history so the next frame cannot look like a jump', () {
      final gate = HandVelocityGate();
      gate.addFrame(vec(0.1));
      gate.reset();
      expect(gate.addFrame(vec(0.9)), isFalse);
    });
  });
}
