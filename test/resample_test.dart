import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sign_vox/core/resample.dart';

Float32List _v(double x) => Float32List.fromList([x]);

void main() {
  group('resampleSequence', () {
    test('preserves the first and last frame exactly', () {
      final frames = [_v(0), _v(1), _v(2), _v(3), _v(4)];
      final out = resampleSequence(frames, 10);
      expect(out.first[0], 0);
      expect(out.last[0], 4);
      expect(out, hasLength(10));
    });

    test('is a no-op in shape when already at the target length', () {
      final frames = [for (var i = 0; i < 32; i++) _v(i.toDouble())];
      final out = resampleSequence(frames, 32);
      for (var i = 0; i < 32; i++) {
        expect(out[i][0], closeTo(i.toDouble(), 1e-6));
      }
    });

    test('linearly interpolates intermediate values when upsampling', () {
      final frames = [_v(0), _v(10)]; // 2 frames spanning 0..10
      final out = resampleSequence(frames, 5);
      // Evenly spaced positions across the single 0->10 segment.
      expect(out[0][0], closeTo(0, 1e-6));
      expect(out[1][0], closeTo(2.5, 1e-6));
      expect(out[2][0], closeTo(5, 1e-6));
      expect(out[3][0], closeTo(7.5, 1e-6));
      expect(out[4][0], closeTo(10, 1e-6));
    });

    test('downsamples a longer sequence to the target length', () {
      final frames = [for (var i = 0; i < 100; i++) _v(i.toDouble())];
      final out = resampleSequence(frames, 32);
      expect(out, hasLength(32));
      expect(out.first[0], closeTo(0, 1e-6));
      expect(out.last[0], closeTo(99, 1e-6));
    });

    test('handles a single-frame input by repeating it', () {
      final out = resampleSequence([_v(7)], 4);
      expect(out, hasLength(4));
      for (final frame in out) {
        expect(frame[0], 7);
      }
    });

    test('throws on an empty sequence rather than silently producing garbage', () {
      expect(() => resampleSequence([], 32), throwsArgumentError);
    });
  });
}
