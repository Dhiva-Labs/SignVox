import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sign_vox/engines/mlp_dart.dart';

void main() {
  // Two tiny 2-in/2-out softmax nets with opposite biases, so each member's
  // output is lopsided a different way and only a true average lands between.
  Map<String, dynamic> net(double bias0, double bias1) => {
    'layers': [
      {
        'weights': [
          [1.0, 0.0],
          [0.0, 1.0],
        ],
        'biases': [bias0, bias1],
        'activation': 'softmax',
      },
    ],
  };

  final ensembleJson = jsonEncode({
    'labels': ['A', 'B'],
    'featureSet': 'raw63',
    'ensemble': 2,
    'models': [net(2.0, 0.0), net(0.0, 2.0)],
  });

  test('ensemble predict is the positionwise mean of member softmaxes', () {
    final model = MlpModel.fromJsonString(ensembleJson);
    expect(model.memberCount, 2);

    final probs = model.predict(Float32List.fromList([0.0, 0.0]));
    // Member 1: softmax(2,0) ≈ (0.8808, 0.1192); member 2 is its mirror.
    // Mean of the pair is exactly (0.5, 0.5).
    expect(probs[0], closeTo(0.5, 1e-4));
    expect(probs[1], closeTo(0.5, 1e-4));

    // Sanity: a single-member file still behaves like that member alone.
    final single = MlpModel.fromJsonString(
      jsonEncode({
        'labels': ['A', 'B'],
        'layers': net(2.0, 0.0)['layers'],
      }),
    );
    expect(single.memberCount, 1);
    final p = single.predict(Float32List.fromList([0.0, 0.0]));
    expect(p[0], greaterThan(0.85));
  });

  test('probabilities always sum to 1 across ensemble members', () {
    final model = MlpModel.fromJsonString(ensembleJson);
    final probs = model.predict(Float32List.fromList([0.7, -0.3]));
    expect(probs[0] + probs[1], closeTo(1.0, 1e-5));
  });

  test('embedding comes from member 0 (stable prototype space)', () {
    // Two-layer members so a penultimate layer exists; member 1 has a relu
    // hidden layer that doubles the input, member 2 zeroes it — the embedding
    // must reflect member 1 only.
    Map<String, dynamic> deepNet(double scale) => {
      'layers': [
        {
          'weights': [
            [scale, 0.0],
            [0.0, scale],
          ],
          'biases': [0.0, 0.0],
          'activation': 'relu',
        },
        {
          'weights': [
            [1.0, 0.0],
            [0.0, 1.0],
          ],
          'biases': [0.0, 0.0],
          'activation': 'softmax',
        },
      ],
    };
    final model = MlpModel.fromJsonString(
      jsonEncode({
        'labels': ['A', 'B'],
        'ensemble': 2,
        'models': [deepNet(2.0), deepNet(0.0)],
      }),
    );
    model.predict(Float32List.fromList([1.0, 3.0]));
    expect(model.penultimate, [2.0, 6.0]);
  });
}
