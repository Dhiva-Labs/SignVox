import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sign_vox/engines/user_prototypes.dart';

/// On-device personalisation (PLAN_V2_RECOGNITION.md R6). Uses synthetic
/// embeddings rather than a real model, so these assert the blend *maths* —
/// whether calibrating a letter actually moves its prediction, and by how much
/// — independently of whichever weights happen to be bundled.
Float32List e(List<double> v) => Float32List.fromList(v);

void main() {
  const labels = ['A', 'B', 'C'];

  test('an uncalibrated model leaves probabilities exactly as they were', () {
    final p = UserPrototypes();
    expect(p.isActive, isFalse);
    final probs = e([0.5, 0.3, 0.2]);
    final out = p.blend(probs, e([1, 0, 0]), labels);
    expect(out[0], closeTo(0.5, 1e-6));
    expect(out[1], closeTo(0.3, 1e-6));
    expect(out[2], closeTo(0.2, 1e-6));
  });

  test('calibrating a letter with deliberately-shifted data moves its prediction', () {
    // The proof that personalisation does something: the model says B, the user
    // has taught this phone that *their* B looks like the embedding the model
    // reads as A, and after enough samples the blended answer follows the user.
    final p = UserPrototypes();
    final userEmbedding = e([1, 0, 0]);
    for (var i = 0; i < 30; i++) {
      p.addSample('B', userEmbedding);
    }

    final probs = e([0.45, 0.40, 0.15]);
    final before = probs[1];
    final out = p.blend(probs, userEmbedding, labels);
    expect(out[1], greaterThan(before));
    expect(out[1], greaterThan(out[0]), reason: 'the user\'s own calibration should now win');
  });

  test('beta ramps with sample count and caps at 0.5', () {
    final p = UserPrototypes();
    expect(p.betaFor('A'), 0.0);
    for (var i = 0; i < 10; i++) {
      p.addSample('A', e([1, 0]));
    }
    expect(p.betaFor('A'), closeTo(10 / 30, 1e-9));
    for (var i = 0; i < 50; i++) {
      p.addSample('A', e([1, 0]));
    }
    expect(p.betaFor('A'), 0.5, reason: 'a handful of captures must never fully override the model');
  });

  test('letters without a prototype are left untouched by the blend', () {
    final p = UserPrototypes();
    for (var i = 0; i < 30; i++) {
      p.addSample('A', e([1, 0, 0]));
    }
    final probs = e([0.2, 0.5, 0.3]);
    final out = p.blend(probs, e([0, 1, 0]), labels);
    // B and C have no prototypes, so their only change is renormalization —
    // their ratio to each other must be exactly preserved.
    expect(out[1] / out[2], closeTo(probs[1] / probs[2], 1e-6));
  });

  test('the blended vector is still a probability distribution', () {
    final p = UserPrototypes();
    for (var i = 0; i < 12; i++) {
      p.addSample('A', e([1, 0, 0]));
      p.addSample('C', e([0, 0, 1]));
    }
    final out = p.blend(e([0.4, 0.35, 0.25]), e([0.9, 0.1, 0.0]), labels);
    var sum = 0.0;
    for (final v in out) {
      sum += v;
      expect(v, inInclusiveRange(0.0, 1.0));
    }
    expect(sum, closeTo(1.0, 1e-5));
  });

  test('the mean prototype is the running mean of every sample', () {
    final p = UserPrototypes();
    p.addSample('A', e([0, 0]));
    p.addSample('A', e([2, 4]));
    // Mean is (1,2); an embedding at (1,2) should beat one at (2,4).
    final atMean = p.blend(e([0.5, 0.5]), e([1, 2]), ['A', 'B']);
    final atEdge = p.blend(e([0.5, 0.5]), e([2, 4]), ['A', 'B']);
    expect(atMean[0], greaterThan(atEdge[0]));
  });

  test('disabling makes it inert without losing what was learned', () {
    final p = UserPrototypes();
    for (var i = 0; i < 30; i++) {
      p.addSample('A', e([1, 0]));
    }
    p.enabled = false;
    expect(p.isActive, isFalse);
    final out = p.blend(e([0.3, 0.7]), e([1, 0]), ['A', 'B']);
    expect(out[0], closeTo(0.3, 1e-6));
    p.enabled = true;
    expect(p.isActive, isTrue);
    expect(p.sampleCountFor('A'), 30);
  });

  test('reset clears everything; per-letter reset clears only that letter', () {
    final p = UserPrototypes();
    p.addSample('A', e([1, 0]));
    p.addSample('B', e([0, 1]));
    p.clearLabel('A');
    expect(p.sampleCountFor('A'), 0);
    expect(p.sampleCountFor('B'), 1);
    p.clear();
    expect(p.letterCount, 0);
    expect(p.isActive, isFalse);
  });

  test('survives a JSON round-trip, counts and all', () {
    final p = UserPrototypes();
    for (var i = 0; i < 7; i++) {
      p.addSample('A', e([1, 2, 3]));
    }
    p.addSample('B', e([4, 5, 6]));

    final restored = UserPrototypes.decode(p.encode());
    expect(restored.sampleCountFor('A'), 7);
    expect(restored.sampleCountFor('B'), 1);
    expect(restored.betaFor('A'), closeTo(p.betaFor('A'), 1e-9));

    final probs = e([0.4, 0.4, 0.2]);
    final a = p.blend(probs, e([1, 2, 3]), labels);
    final b = restored.blend(probs, e([1, 2, 3]), labels);
    for (var i = 0; i < a.length; i++) {
      expect(b[i], closeTo(a[i], 1e-4));
    }
  });

  test('a prototype from a different embedding size is ignored, not crashed on', () {
    // Happens the first time a user updates the app to a model with a different
    // hidden layer. Silently ignoring beats throwing on every frame.
    final p = UserPrototypes();
    for (var i = 0; i < 30; i++) {
      p.addSample('A', e([1, 0, 0, 0]));
    }
    final out = p.blend(e([0.6, 0.4]), e([1, 0]), ['A', 'B']);
    expect(out[0], closeTo(0.6, 1e-6));
    expect(out[1], closeTo(0.4, 1e-6));
  });
}
