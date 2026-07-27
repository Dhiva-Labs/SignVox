import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sign_vox/engines/mlp_dart.dart';

void main() {
  group('MlpModel', () {
    test('applies weights, biases, and ReLU correctly for a single dense layer', () {
      // out0 = 2*1 + 1*1 + bias(1) = 4 -> relu -> 4
      // out1 = 0*1 + -1*1 + bias(0) = -1 -> relu -> 0
      final model = MlpModel.fromJson({
        'labels': ['x', 'y'],
        'layers': [
          {
            'weights': [
              [2, 1],
              [0, -1],
            ],
            'biases': [1, 0],
            'activation': 'relu',
          },
        ],
      });

      final out = model.predict(Float32List.fromList([1, 1]));
      expect(out[0], closeTo(4.0, 1e-4));
      expect(out[1], closeTo(0.0, 1e-4));
    });

    test('chains multiple layers and applies softmax on the output layer', () {
      // Layer 1 (identity, relu): [3, -2] -> [3, -2] -> relu -> [3, 0]
      // Layer 2 (identity, softmax): softmax([3, 0])
      final model = MlpModel.fromJson({
        'labels': ['a', 'b'],
        'layers': [
          {
            'weights': [
              [1, 0],
              [0, 1],
            ],
            'biases': [0, 0],
            'activation': 'relu',
          },
          {
            'weights': [
              [1, 0],
              [0, 1],
            ],
            'biases': [0, 0],
            'activation': 'softmax',
          },
        ],
      });

      final out = model.predict(Float32List.fromList([3, -2]));
      final expDiff = math.exp(0.0 - 3.0); // exp(0-3) relative to the max
      final expected0 = 1 / (1 + expDiff);
      final expected1 = expDiff / (1 + expDiff);
      expect(out[0], closeTo(expected0, 1e-4));
      expect(out[1], closeTo(expected1, 1e-4));
      expect(out[0] + out[1], closeTo(1.0, 1e-5));
    });

    test('softmax output always sums to 1 and picks the largest logit as most probable', () {
      final model = MlpModel.fromJson({
        'labels': ['a', 'b', 'c'],
        'layers': [
          {
            'weights': [
              [1, 0],
              [0, 1],
              [1, 1],
            ],
            'biases': [0, 0, 0],
            'activation': 'softmax',
          },
        ],
      });
      final out = model.predict(Float32List.fromList([5, -5]));
      final sum = out[0] + out[1] + out[2];
      expect(sum, closeTo(1.0, 1e-5));
      // Logit for 'a' is 5, for 'b' is -5, for 'c' is 0 -> 'a' should win clearly.
      expect(out[0], greaterThan(out[1]));
      expect(out[0], greaterThan(out[2]));
    });
  });
}
