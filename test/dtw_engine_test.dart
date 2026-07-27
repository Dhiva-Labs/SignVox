import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sign_vox/engines/dtw_engine.dart';

Float32List _v(List<double> values) => Float32List.fromList(values);

/// A synthetic "sign": each frame's single feature ramps linearly from
/// [start] to [end] over [length] frames — stands in for a real 129-dim
/// normalized landmark sequence for testing purposes (PLAN.md explicitly
/// asks for DTW to be unit-tested with synthetic sequences, not real
/// recordings).
List<Float32List> _ramp(double start, double end, int length) {
  return [
    for (var i = 0; i < length; i++) _v([start + (end - start) * i / (length - 1)]),
  ];
}

void main() {
  group('dtwDistance', () {
    test('is zero for identical sequences', () {
      final seq = _ramp(0, 1, 32);
      expect(dtwDistance(seq, seq), 0.0);
    });

    test('is much larger between clearly different patterns than between similar ones', () {
      final rampUp = _ramp(0, 1, 32);
      final rampUpAgain = _ramp(0.05, 0.95, 32); // same shape, slightly different endpoints
      final rampDown = _ramp(1, 0, 32);

      final similar = dtwDistance(rampUp, rampUpAgain);
      final different = dtwDistance(rampUp, rampDown);
      expect(similar, lessThan(different));
    });

    test('tolerates timing stretch — the whole reason to use DTW over raw Euclidean distance', () {
      final original = _ramp(0, 1, 32);
      // Same shape, but held at the start for longer and compressed at the
      // end — a plain frame-by-frame distance would be thrown off by this;
      // DTW should still recognize it as close.
      final stretched = [
        ..._ramp(0, 0.2, 10),
        ..._ramp(0.2, 1, 22),
      ];
      final differentShape = _ramp(1, 0, 32);

      final stretchedScore = dtwDistance(original, stretched);
      final differentScore = dtwDistance(original, differentShape);
      expect(stretchedScore, lessThan(differentScore));
    });
  });

  group('DtwEngine.computeThreshold', () {
    test('returns the floor when fewer than 2 exemplars are given', () {
      final engine = DtwEngine();
      expect(engine.computeThreshold([], floor: 0.2), 0.2);
      expect(engine.computeThreshold([_ramp(0, 1, 32)], floor: 0.2), 0.2);
    });

    test('grows with exemplar spread (mean + 2*stddev of pairwise distances)', () {
      final engine = DtwEngine();
      final tight = [_ramp(0, 1, 32), _ramp(0.01, 1.01, 32), _ramp(-0.01, 0.99, 32)];
      final loose = [_ramp(0, 1, 32), _ramp(0.3, 1.3, 32), _ramp(-0.3, 0.7, 32)];

      final tightThreshold = engine.computeThreshold(tight, floor: 0.0);
      final looseThreshold = engine.computeThreshold(loose, floor: 0.0);
      expect(looseThreshold, greaterThan(tightThreshold));
    });
  });

  group('DtwEngine.classify', () {
    late DtwEngine engine;
    late List<Float32List> rampUpExemplar;
    late List<Float32List> rampDownExemplar;
    late Map<int, List<List<Float32List>>> exemplars;
    late Map<int, double> thresholds;

    setUp(() {
      engine = DtwEngine();
      rampUpExemplar = _ramp(0, 1, 32);
      rampDownExemplar = _ramp(1, 0, 32);
      exemplars = {
        1: [rampUpExemplar, _ramp(0.02, 0.98, 32)],
        2: [rampDownExemplar, _ramp(0.98, 0.02, 32)],
      };
      // Generous thresholds computed the same way teach mode would.
      thresholds = {
        1: engine.computeThreshold(exemplars[1]!, floor: 0.05),
        2: engine.computeThreshold(exemplars[2]!, floor: 0.05),
      };
    });

    test('accepts a clean match to the right sign', () {
      final query = _ramp(0.01, 0.99, 32); // close to sign 1's exemplars
      final match = engine.classify(query, exemplars, thresholds);
      expect(match, isNotNull);
      expect(match!.signId, 1);
      expect(match.accepted, isTrue);
    });

    test('rejects a gesture that matches no taught sign well', () {
      final unrelated = [
        for (var i = 0; i < 32; i++) _v([i.isEven ? 5.0 : -5.0]), // wild oscillation, unlike either sign
      ];
      final match = engine.classify(unrelated, exemplars, thresholds);
      expect(match, isNotNull);
      expect(match!.accepted, isFalse, reason: 'an unrecognized gesture should be rejected, not force-matched');
    });

    test('returns null when there are no signs to compare against', () {
      final match = engine.classify(rampUpExemplar, {}, {});
      expect(match, isNull);
    });

    test('rejects when the top two signs score too close together (the margin rule)', () {
      // A query exactly halfway between two very different signs' shapes —
      // both should score comparably badly, so neither should confidently win.
      final ambiguous = _ramp(0.5, 0.5, 32);
      final closeThresholds = {
        1: 1000.0, // deliberately generous so only the margin rule can reject
        2: 1000.0,
      };
      final match = engine.classify(ambiguous, exemplars, closeThresholds);
      expect(match, isNotNull);
      expect(match!.accepted, isFalse);
    });
  });
}
