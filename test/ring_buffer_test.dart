import 'package:flutter_test/flutter_test.dart';
import 'package:sign_vox/core/ring_buffer.dart';

void main() {
  group('RingBuffer', () {
    test('starts empty', () {
      final buf = RingBuffer<int>(3);
      expect(buf.length, 0);
      expect(buf.isFull, isFalse);
      expect(buf.last, isNull);
      expect(buf.toList(), <int>[]);
    });

    test('grows up to capacity while preserving insertion order', () {
      final buf = RingBuffer<int>(3);
      buf.add(1);
      buf.add(2);
      expect(buf.length, 2);
      expect(buf.isFull, isFalse);
      expect(buf.toList(), [1, 2]);
      expect(buf.last, 2);
    });

    test('evicts the oldest item once capacity is exceeded', () {
      final buf = RingBuffer<int>(3)
        ..add(1)
        ..add(2)
        ..add(3)
        ..add(4);
      expect(buf.length, 3);
      expect(buf.isFull, isTrue);
      expect(buf.toList(), [2, 3, 4]);
      expect(buf.last, 4);
    });

    test('keeps working correctly across multiple wraparounds', () {
      final buf = RingBuffer<int>(3);
      for (var i = 1; i <= 10; i++) {
        buf.add(i);
      }
      expect(buf.toList(), [8, 9, 10]);
      expect(buf.last, 10);
    });

    test('clear resets to empty and forgets prior contents', () {
      final buf = RingBuffer<int>(3)
        ..add(1)
        ..add(2)
        ..clear();
      expect(buf.length, 0);
      expect(buf.toList(), <int>[]);
      buf.add(9);
      expect(buf.toList(), [9]);
    });
  });
}
