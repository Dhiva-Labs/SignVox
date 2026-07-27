import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sign_vox/core/landmark_frame.dart';
import 'package:sign_vox/core/normalize.dart';
import 'package:sign_vox/engines/letter_features.dart';

/// Train/serve parity gate (PLAN_V2_RECOGNITION.md R-5).
///
/// `tools/letter_features.py` computes the features the model is *trained* on;
/// `lib/engines/letter_features.dart` computes the ones it *infers* on. If they
/// drift apart the model still trains beautifully and still runs happily — it
/// just quietly predicts nonsense on device, which is precisely the failure
/// mode this whole overhaul exists to fix. So the Python side writes fixtures
/// and this test asserts the Dart side reproduces them.
///
/// Regenerate with: `cd tools && ./.venv/bin/python make_fixtures.py`
void main() {
  late Map<String, dynamic> fixture;

  setUpAll(() {
    final file = File('test/fixtures/letter_features_v2.json');
    fixture = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  });

  test('fixture file declares the feature set this build implements', () {
    expect(fixture['featureSet'], 'v2');
    expect(fixture['featureDim'], featureDimV2);
  });

  test('normalizeHand matches the Python training-time port on every fixture case', () {
    final cases = (fixture['cases'] as List).cast<Map<String, dynamic>>();
    var checked = 0;
    for (final c in cases) {
      if (c['raw'] == null) continue; // features-only case
      final raw = Float32List.fromList(
        (c['raw'] as List).map((v) => (v as num).toDouble()).toList(growable: false),
      );
      final expected = (c['normalized'] as List).map((v) => (v as num).toDouble()).toList();
      final hand = HandLandmarks(isLeft: c['isLeft'] as bool, score: 1.0, landmarks: raw);
      final actual = normalizeHand(hand);

      expect(actual.length, expected.length, reason: c['name'] as String);
      for (var i = 0; i < expected.length; i++) {
        expect(actual[i], closeTo(expected[i], 1e-4), reason: '${c['name']} normalized[$i]');
      }
      checked++;
    }
    expect(checked, greaterThan(0));
  });

  test('featuresV2 matches the Python training-time port on every fixture case', () {
    final cases = (fixture['cases'] as List).cast<Map<String, dynamic>>();
    for (final c in cases) {
      final normalized = Float32List.fromList(
        (c['normalized'] as List).map((v) => (v as num).toDouble()).toList(growable: false),
      );
      final expected = (c['features'] as List).map((v) => (v as num).toDouble()).toList();
      final actual = featuresV2(normalized);

      expect(actual.length, featureDimV2, reason: c['name'] as String);
      expect(expected.length, featureDimV2, reason: c['name'] as String);
      for (var i = 0; i < featureDimV2; i++) {
        expect(actual[i], closeTo(expected[i], 1e-4), reason: '${c['name']} features[$i]');
      }
    }
  });

  test('featuresV2 writes into a caller-supplied buffer without allocating a new one', () {
    final normalized = Float32List.fromList(
      ((fixture['cases'] as List).first as Map<String, dynamic>)['normalized']
          .cast<num>()
          .map((v) => v.toDouble())
          .toList(growable: false)
          .cast<double>(),
    );
    final buffer = Float32List(featureDimV2);
    final result = featuresV2(normalized, out: buffer);
    expect(identical(result, buffer), isTrue);

    final fresh = featuresV2(normalized);
    for (var i = 0; i < featureDimV2; i++) {
      expect(buffer[i], fresh[i]);
    }
  });

  test('rotation-canonicalized block is invariant to in-plane hand rotation', () {
    // The whole point of splitting shape from orientation: rotating the hand in
    // the image plane must leave 68..109 alone while moving 63..64.
    final raw = Float32List(63);
    for (var i = 0; i < 21; i++) {
      raw[i * 3] = 0.5 + 0.02 * i;
      raw[i * 3 + 1] = 0.8 - 0.015 * i;
      raw[i * 3 + 2] = 0.001 * i;
    }
    final base = featuresV2(normalizeHand(
      HandLandmarks(isLeft: false, score: 1.0, landmarks: raw),
    ));
    final baseShape = Float32List.fromList(base.sublist(68, 110));
    final baseSin = base[63];

    const angle = 0.6;
    final rotated = Float32List(63);
    for (var i = 0; i < 21; i++) {
      final x = raw[i * 3] - 0.5, y = raw[i * 3 + 1] - 0.8;
      rotated[i * 3] = 0.5 + x * 0.8253356 - y * 0.5646425; // cos/sin(0.6)
      rotated[i * 3 + 1] = 0.8 + x * 0.5646425 + y * 0.8253356;
      rotated[i * 3 + 2] = raw[i * 3 + 2];
    }
    final after = featuresV2(normalizeHand(
      HandLandmarks(isLeft: false, score: 1.0, landmarks: rotated),
    ));

    for (var i = 0; i < 42; i++) {
      expect(after[68 + i], closeTo(baseShape[i], 1e-3), reason: 'canonical shape dim $i');
    }
    expect((after[63] - baseSin).abs(), greaterThan(0.1),
        reason: 'orientation features must still record the $angle rad rotation');
  });
}
