import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sign_vox/core/motion_energy.dart';

Float32List _vec(double a, double b) => Float32List.fromList([a, b]);

/// Alternates between two far-apart vectors so every consecutive pair has a
/// large mean-abs-difference — comfortably above any noise-floor threshold
/// the segmenter would calibrate to from idle frames.
List<Float32List> _motionFrames(int count) {
  return [for (var i = 0; i < count; i++) _vec(i.isEven ? 1.0 : -1.0, 0.0)];
}

List<Float32List> _idleFrames(int count) => [for (var i = 0; i < count; i++) _vec(0.0, 0.0)];

void main() {
  group('MotionEnergySegmenter', () {
    test('confirms and completes a segment for a clear motion burst', () {
      final seg = MotionEnergySegmenter();
      final results = <List<Float32List>>[];

      for (final f in _idleFrames(5)) {
        final r = seg.addFrame(f);
        if (r != null) results.add(r);
      }
      expect(seg.isInSegment, isFalse);

      for (final f in _motionFrames(20)) {
        final r = seg.addFrame(f);
        if (r != null) results.add(r);
      }
      expect(seg.isInSegment, isTrue, reason: 'a sustained motion burst should confirm a segment start');

      for (final f in _idleFrames(15)) {
        final r = seg.addFrame(f);
        if (r != null) results.add(r);
      }
      expect(seg.isInSegment, isFalse, reason: 'a long-enough idle stretch should close the segment');

      expect(results, hasLength(1));
      expect(results.single.length, greaterThanOrEqualTo(seg.minSegmentFrames));
      expect(results.single.length, lessThanOrEqualTo(seg.maxSegmentFrames));
    });

    test('a blip shorter than startFrames never starts a segment', () {
      final seg = MotionEnergySegmenter();
      final results = <List<Float32List>>[];

      // A single up-and-back-down bump: two above-threshold transitions
      // (0->0.5, 0.5->0), one short of startFrames=3, then settles. Note
      // this can't reuse _motionFrames' alternating +-1 pattern here — its
      // own "snap back to idle" transition is itself a large jump, which
      // would supply a spurious 3rd high reading and confirm a segment.
      final blip = [_vec(0.5, 0.0), _vec(0.0, 0.0)];
      for (final f in [..._idleFrames(5), ...blip, ..._idleFrames(10)]) {
        final r = seg.addFrame(f);
        if (r != null) results.add(r);
        expect(seg.isInSegment, isFalse, reason: 'two above-threshold transitions is below startFrames=3, should never confirm');
      }
      expect(results, isEmpty);
    });

    test('discards a segment that runs longer than maxSegmentFrames', () {
      final seg = MotionEnergySegmenter(maxSegmentFrames: 15);
      final results = <List<Float32List>>[];
      var wasEverInSegment = false;

      for (final f in [..._idleFrames(5), ..._motionFrames(25), ..._idleFrames(15)]) {
        final r = seg.addFrame(f);
        if (r != null) results.add(r);
        if (seg.isInSegment) wasEverInSegment = true;
      }

      expect(wasEverInSegment, isTrue, reason: 'the burst should still confirm a start');
      expect(seg.isInSegment, isFalse, reason: 'it should also close out again once idle resumes');
      expect(results, isEmpty, reason: 'a segment over maxSegmentFrames must be discarded, not returned');
    });

    test('discards a segment shorter than an explicit minSegmentFrames', () {
      // With default params, any confirmed-then-closed segment is at least
      // startFrames + endFrames long, which already exceeds the default
      // minSegmentFrames — so exercising the "too short" path needs a
      // deliberately larger minimum than the built-in start/end costs.
      final seg = MotionEnergySegmenter(minSegmentFrames: 30);
      final results = <List<Float32List>>[];
      var wasEverInSegment = false;

      for (final f in [..._idleFrames(5), ..._motionFrames(3), ..._idleFrames(15)]) {
        final r = seg.addFrame(f);
        if (r != null) results.add(r);
        if (seg.isInSegment) wasEverInSegment = true;
      }

      expect(wasEverInSegment, isTrue);
      expect(seg.isInSegment, isFalse);
      expect(results, isEmpty);
    });
  });
}
