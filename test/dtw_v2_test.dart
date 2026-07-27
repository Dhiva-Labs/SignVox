import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sign_vox/engines/dtw_engine.dart';

/// v1.1 DTW robustness (PLAN_V2_RECOGNITION.md R4). `dtw_engine_test.dart`
/// holds the v1.0 behaviour these must not break.
List<Float32List> _randomSequence(math.Random rng, {int frames = 32, int dim = 129}) {
  return List.generate(
    frames,
    (_) => Float32List.fromList(List.generate(dim, (_) => rng.nextDouble())),
  );
}

void main() {
  group('early abandonment', () {
    test('returns exactly the full-DTW score whenever it does not abandon', () {
      // Exactness matters more than speed here: an early-abandon bug would
      // silently change which sign wins, and nothing else would notice.
      final rng = math.Random(11);
      for (var trial = 0; trial < 25; trial++) {
        final a = _randomSequence(rng, frames: 20, dim: 12);
        final b = _randomSequence(rng, frames: 20, dim: 12);
        final full = dtwDistance(a, b);
        final generous = dtwDistance(a, b, abandonAbove: full + 1.0);
        expect(generous, closeTo(full, 1e-9));
      }
    });

    test('abandons (returns infinity) when the bound is already beaten', () {
      final rng = math.Random(12);
      final a = _randomSequence(rng, frames: 20, dim: 12);
      final b = _randomSequence(rng, frames: 20, dim: 12);
      expect(dtwDistance(a, b, abandonAbove: 0.0), double.infinity);
    });

    test('never abandons a sequence compared with itself under any positive bound', () {
      final rng = math.Random(13);
      final a = _randomSequence(rng, frames: 24, dim: 8);
      expect(dtwDistance(a, a, abandonAbove: 1e-9), 0.0);
    });

    test('classify picks the same winner with abandonment as a brute-force search', () {
      final rng = math.Random(14);
      final query = _randomSequence(rng, frames: 16, dim: 6);
      final exemplars = <int, List<List<Float32List>>>{
        1: [_randomSequence(rng, frames: 16, dim: 6), query], // exact match lives here
        2: [_randomSequence(rng, frames: 16, dim: 6)],
        3: [_randomSequence(rng, frames: 16, dim: 6)],
      };
      const engine = DtwEngine();
      final match = engine.classify(query, exemplars, {1: 1.0, 2: 1.0, 3: 1.0});
      expect(match, isNotNull);
      expect(match!.signId, 1);
      expect(match.score, closeTo(0.0, 1e-9));
      expect(match.accepted, isTrue);
    });
  });

  group('z down-weighting', () {
    test('a pure-z difference costs less than the same difference in x', () {
      Float32List frame(int axis, double value) {
        final f = Float32List(129);
        f[axis] = value;
        return f;
      }

      final base = [for (var i = 0; i < 4; i++) Float32List(129)];
      final shiftedX = [for (var i = 0; i < 4; i++) frame(0, 0.5)]; // lm0_x
      final shiftedZ = [for (var i = 0; i < 4; i++) frame(2, 0.5)]; // lm0_z

      final dx = dtwDistance(base, shiftedX);
      final dz = dtwDistance(base, shiftedZ);
      expect(dz, closeTo(dx * dtwZWeight, 1e-6));
    });

    test('the trailing non-landmark dims are not treated as z', () {
      // 126 = other-hand-present flag, 127/128 = inter-wrist offset. Damping
      // those by accident would quietly weaken two-handed sign discrimination.
      Float32List frame(int index) {
        final f = Float32List(129);
        f[index] = 0.5;
        return f;
      }

      final base = [for (var i = 0; i < 4; i++) Float32List(129)];
      final dx = dtwDistance(base, [for (var i = 0; i < 4; i++) frame(0)]);
      for (final index in [126, 127, 128]) {
        expect(
          dtwDistance(base, [for (var i = 0; i < 4; i++) frame(index)]),
          closeTo(dx, 1e-6),
          reason: 'dim $index must be full weight',
        );
      }
    });
  });

  group('exemplar augmentation', () {
    test('produces the original plus perExemplar virtuals, same shape', () {
      final rng = math.Random(15);
      final exemplars = [for (var i = 0; i < 5; i++) _randomSequence(rng, frames: 32, dim: 129)];
      final augmented = augmentExemplars(exemplars, perExemplar: 2);
      expect(augmented.length, 15);
      for (final seq in augmented) {
        expect(seq.length, 32);
        expect(seq.first.length, 129);
      }
      // The originals are preserved by identity, not copied-and-perturbed.
      for (final original in exemplars) {
        expect(augmented.any((s) => identical(s, original)), isTrue);
      }
    });

    test('virtuals are close to their source but not identical to it', () {
      // A *smooth* trajectory, not white noise: time-warping is meant to model
      // the same sign performed a bit faster or slower, and a real landmark
      // sequence moves continuously. Warping uncorrelated noise would look
      // catastrophic here for reasons that never occur in practice.
      final exemplar = [
        for (var t = 0; t < 32; t++)
          Float32List.fromList([
            for (var d = 0; d < 129; d++) math.sin((t / 31) * math.pi + d * 0.05) * 0.5,
          ])
      ];
      final augmented = augmentExemplars([exemplar], perExemplar: 2);
      final virtuals = augmented.where((s) => !identical(s, exemplar)).toList();
      expect(virtuals, hasLength(2));
      for (final v in virtuals) {
        final d = dtwDistance(exemplar, v);
        expect(d, greaterThan(0.0), reason: 'a virtual identical to its source teaches nothing');
        expect(d, lessThan(1.0), reason: 'a virtual too far from its source is not the same sign');
      }
    });

    test('is a no-op when asked for zero variants or given nothing', () {
      final rng = math.Random(17);
      final exemplars = [_randomSequence(rng, frames: 8, dim: 4)];
      expect(identical(augmentExemplars(exemplars, perExemplar: 0), exemplars), isTrue);
      expect(augmentExemplars(const [], perExemplar: 2), isEmpty);
    });
  });

  group('leave-one-out thresholds', () {
    test('a tightly-taught sign gets a tighter threshold than a sloppy one', () {
      final rng = math.Random(18);
      final core = _randomSequence(rng, frames: 32, dim: 16);

      List<Float32List> perturb(double sigma) => [
            for (final f in core)
              Float32List.fromList([
                for (final v in f) v + (rng.nextDouble() - 0.5) * sigma,
              ])
          ];

      const engine = DtwEngine();
      final tight = engine.computeThreshold([for (var i = 0; i < 6; i++) perturb(0.02)], floor: 0.0);
      final sloppy = engine.computeThreshold([for (var i = 0; i < 6; i++) perturb(0.5)], floor: 0.0);
      expect(tight, lessThan(sloppy));
    });

    test('measures nearest-neighbour distance, which is what classify compares', () {
      // Two tight clusters of three. Pairwise distances are dominated by the
      // *between*-cluster pairs; nearest-neighbour distances are not. The v1.0
      // mean-of-all-pairs threshold was therefore far looser than the quantity
      // it was gating.
      final rng = math.Random(19);
      final a = _randomSequence(rng, frames: 16, dim: 8);
      final b = _randomSequence(rng, frames: 16, dim: 8);
      List<Float32List> near(List<Float32List> seed) => [
            for (final f in seed)
              Float32List.fromList([for (final v in f) v + (rng.nextDouble() - 0.5) * 0.01])
          ];
      final exemplars = [a, near(a), near(a), b, near(b), near(b)];

      const engine = DtwEngine();
      final loo = engine.computeThreshold(exemplars, floor: 0.0);
      final betweenClusters = dtwDistance(a, b);
      expect(loo, lessThan(betweenClusters),
          reason: 'the threshold must reflect within-cluster spread, not the gap between clusters');
    });

    test('keeps the floor for a single exemplar', () {
      const engine = DtwEngine();
      final rng = math.Random(20);
      expect(engine.computeThreshold([_randomSequence(rng, frames: 8, dim: 4)]), 0.15);
    });
  });

  group('score to confidence', () {
    test('a perfect match reads as ~100% and a distant one as near 0', () {
      final rng = math.Random(21);
      final query = _randomSequence(rng, frames: 16, dim: 6);
      const engine = DtwEngine();

      final exact = engine.classify(query, {1: [query]}, {1: 0.5});
      expect(exact!.confidence, closeTo(1.0, 1e-6));

      final far = _randomSequence(rng, frames: 16, dim: 6);
      final distant = engine.classify(query, {1: [far]}, {1: 0.01});
      expect(distant!.confidence, lessThan(0.2));
    });
  });
}
