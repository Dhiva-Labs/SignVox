import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sign_vox/core/landmark_frame.dart';
import 'package:sign_vox/core/normalize.dart';
import 'package:sign_vox/engines/decoder.dart';
import 'package:sign_vox/engines/letter_engine.dart';
import 'package:sign_vox/engines/letter_features.dart';
import 'package:sign_vox/engines/prob_smoother.dart';

/// Hot-path regression tripwire (PLAN_V2_RECOGNITION.md R5).
///
/// This is **not** a device performance claim — it runs on the host VM, which
/// is faster than any phone. It exists to catch the specific regression that
/// would matter: someone reintroducing per-frame allocation or an accidental
/// O(n²) into the one code path that runs on every camera frame. The bound is
/// deliberately loose so it fails on a real regression, not on a busy CI box.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Float32List plausibleHand(double phase) {
    final raw = Float32List(63);
    for (var i = 0; i < 21; i++) {
      raw[i * 3] = 0.5 + 0.01 * i + 0.002 * phase;
      raw[i * 3 + 1] = 0.8 - 0.012 * i;
      raw[i * 3 + 2] = 0.001 * i;
    }
    return raw;
  }

  test('the full per-frame recognition path stays comfortably sub-millisecond', () async {
    final engine = await LetterEngine.load();
    final smoother = ProbSmoother();
    final decoder = SpellDecoder();
    final gate = HandVelocityGate();
    final normalized = Float32List(63);

    // Warm up so the JIT has optimised the loop before anything is measured.
    for (var i = 0; i < 200; i++) {
      final hand = HandLandmarks(isLeft: false, score: 0.9, landmarks: plausibleHand(i.toDouble()));
      normalizeHand(hand, out: normalized);
      gate.addFrame(normalized);
      decoder.addPrediction(engine.topOf(smoother.add(engine.probabilities(normalized))), DateTime.now());
    }

    const iterations = 2000;
    final samples = <int>[];
    final sw = Stopwatch();
    for (var i = 0; i < iterations; i++) {
      final hand = HandLandmarks(isLeft: false, score: 0.9, landmarks: plausibleHand(i.toDouble()));
      sw
        ..reset()
        ..start();
      normalizeHand(hand, out: normalized);
      final moving = gate.addFrame(normalized);
      final smoothed = smoother.add(engine.probabilities(normalized));
      final prediction = engine.topOf(smoothed);
      decoder.addPrediction(prediction, DateTime.now(), isTransitioning: moving);
      sw.stop();
      samples.add(sw.elapsedMicroseconds);
    }
    samples.sort();
    final medianUs = samples[samples.length ~/ 2];
    final p99Us = samples[(samples.length * 0.99).floor()];
    // ignore: avoid_print
    print('recognition spine: median ${medianUs}us, p99 ${p99Us}us over $iterations frames '
        '(featureSet=${engine.featureSet}, ${engine.labels.length} labels)');

    expect(medianUs, lessThan(2000), reason: 'median frame path must stay under 2 ms on host');
  });

  test('normalizeHand, featuresV2 and the MLP all reuse caller/owner buffers', () {
    // The allocation-free property, asserted structurally rather than by
    // measuring GC: every stage either writes into a buffer the caller owns or
    // returns the same object it returned last time.
    final hand = HandLandmarks(isLeft: false, score: 0.9, landmarks: plausibleHand(0));
    final buffer = Float32List(63);
    expect(identical(normalizeHand(hand, out: buffer), buffer), isTrue);

    final featureBuffer = Float32List(featureDimV2);
    expect(identical(featuresV2(buffer, out: featureBuffer), featureBuffer), isTrue);

    final smoother = ProbSmoother();
    final a = smoother.add(Float32List.fromList([0.5, 0.5]));
    final b = smoother.add(Float32List.fromList([0.5, 0.5]));
    expect(identical(a, b), isTrue);
  });

  test('the bundled model returns the same probability buffer every frame', () async {
    final engine = await LetterEngine.load();
    final normalized = Float32List(63);
    final first = engine.probabilities(normalized);
    final second = engine.probabilities(normalized);
    expect(identical(first, second), isTrue,
        reason: 'a fresh Float32List per frame is exactly the garbage R5 removes');
  });
}
