import 'package:flutter_test/flutter_test.dart';
import 'package:sign_vox/engines/decoder.dart';
import 'package:sign_vox/engines/letter_engine.dart';

/// v1.1 decoder behaviour (PLAN_V2_RECOGNITION.md R3). The v1.0 tests in
/// `decoder_test.dart` still pass unchanged and are the regression net; these
/// cover what is genuinely new.
void main() {
  late DateTime now;
  setUp(() => now = DateTime(2026, 1, 1));
  DateTime tick([int ms = 33]) => now = now.add(Duration(milliseconds: ms));

  LetterPrediction p(String label, {double conf = 0.95, String? runnerUp, double runnerUpConf = 0.0}) =>
      LetterPrediction(
        label: label,
        confidence: conf,
        runnerUpLabel: runnerUp,
        runnerUpConfidence: runnerUpConf,
      );

  group('time-based hold', () {
    test('commit latency is the same wall-clock time regardless of frame rate', () {
      // The bug this replaces: at 30 FPS an 8-frame hold was 264 ms, at 10 FPS
      // it was 800 ms — the same setting felt like a different app on a slower
      // or thermally-throttled phone.
      Duration timeToCommit(int frameIntervalMs) {
        final decoder = SpellDecoder(holdDuration: const Duration(milliseconds: 350));
        final start = now;
        for (var i = 0; i < 200; i++) {
          final r = decoder.addPrediction(p('A'), tick(frameIntervalMs));
          if (r.committedLetter != null) return now.difference(start);
        }
        fail('never committed at ${frameIntervalMs}ms/frame');
      }

      final fast = timeToCommit(33); // ~30 FPS
      now = DateTime(2026, 1, 1);
      final slow = timeToCommit(100); // ~10 FPS

      // Both land near the 350 ms target. They cannot be *identical*: a hold
      // can only end on a frame boundary, so 10 FPS carries up to 100 ms of
      // quantization. What matters is that the gap is now about one frame
      // interval rather than the 536 ms (264 vs 800) the old 8-frame rule gave.
      expect(fast.inMilliseconds, inInclusiveRange(340, 420));
      expect(slow.inMilliseconds, inInclusiveRange(340, 560));
      expect((fast - slow).abs().inMilliseconds, lessThanOrEqualTo(150));
    });

    test('a long frame gap contributes only maxFrameGap, not its full length', () {
      // Otherwise backgrounding the app for 10 s would commit whatever letter
      // happened to be on screen when it came back.
      final decoder = SpellDecoder(
        holdDuration: const Duration(milliseconds: 350),
        maxFrameGap: const Duration(milliseconds: 200),
      );
      decoder.addPrediction(p('A'), tick());
      final r = decoder.addPrediction(p('A'), tick(10000));
      expect(r.committedLetter, isNull);
      expect(decoder.holdProgress, lessThan(1.0));
    });

    test('holdFrames setter and getter round-trip through the duration', () {
      final decoder = SpellDecoder(holdFrames: 9);
      expect(decoder.holdDuration.inMilliseconds, 9 * SpellDecoder.msPerFrameEstimate);
      expect(decoder.holdFrames, 9);
      decoder.holdFrames = 12;
      expect(decoder.holdDuration.inMilliseconds, 12 * SpellDecoder.msPerFrameEstimate);
    });
  });

  group('flicker grace', () {
    test('two flickered frames of another letter do not reset the hold', () {
      final decoder = SpellDecoder(holdDuration: const Duration(milliseconds: 330), flickerGrace: 2);
      for (var i = 0; i < 5; i++) {
        expect(decoder.addPrediction(p('A'), tick()).committedLetter, isNull);
      }
      final before = decoder.holdProgress;
      // Two glitched frames — the old decoder threw the whole hold away here.
      decoder.addPrediction(p('S'), tick());
      decoder.addPrediction(p('S'), tick());
      expect(decoder.candidateLabel, 'A', reason: 'A must still own the hold');
      expect(decoder.holdProgress, before, reason: 'grace frames neither advance nor reset');

      for (var i = 0; i < 5; i++) {
        final r = decoder.addPrediction(p('A'), tick());
        if (r.committedLetter != null) {
          expect(r.committedLetter, 'A');
          return;
        }
      }
      fail('A never committed after a survivable flicker');
    });

    test('three consecutive frames of another letter take over, retroactively', () {
      // Switching letters must not cost the grace frames — otherwise every
      // deliberate letter change would be slower than the first one.
      final decoder = SpellDecoder(holdDuration: const Duration(milliseconds: 264), flickerGrace: 2);
      for (var i = 0; i < 4; i++) {
        decoder.addPrediction(p('A'), tick());
      }
      var committed = <String>[];
      for (var i = 0; i < 8; i++) {
        final r = decoder.addPrediction(p('B'), tick());
        if (r.committedLetter != null) committed.add(r.committedLetter!);
      }
      expect(committed, ['B']);
      // 264 ms / 33 ms = 8 frames: exactly the frame count it would take if B
      // had owned the hold from its very first frame.
      expect(decoder.currentWord, 'B');
    });

    test('a none frame resets immediately — it is a verdict, not a glitch', () {
      final decoder = SpellDecoder(holdDuration: const Duration(milliseconds: 264));
      for (var i = 0; i < 5; i++) {
        decoder.addPrediction(p('A'), tick());
      }
      decoder.addPrediction(p('none'), tick());
      expect(decoder.candidateLabel, isNull);
      expect(decoder.holdProgress, 0.0);
    });
  });

  group('margin gate', () {
    test('a confident but ambiguous prediction does not commit', () {
      final decoder = SpellDecoder(
        holdDuration: const Duration(milliseconds: 264),
        commitMargin: 0.15,
      );
      for (var i = 0; i < 30; i++) {
        // M at 0.90 with N right behind at 0.85: high confidence, no separation.
        final r = decoder.addPrediction(
          p('M', conf: 0.90, runnerUp: 'N', runnerUpConf: 0.85),
          tick(),
        );
        expect(r.committedLetter, isNull);
      }
      expect(decoder.currentWord, isEmpty);
    });

    test('the same confidence commits once the runner-up falls away', () {
      final decoder = SpellDecoder(
        holdDuration: const Duration(milliseconds: 264),
        commitMargin: 0.15,
      );
      String? committed;
      for (var i = 0; i < 30; i++) {
        final r = decoder.addPrediction(
          p('M', conf: 0.90, runnerUp: 'N', runnerUpConf: 0.05),
          tick(),
        );
        committed ??= r.committedLetter;
      }
      expect(committed, 'M');
    });

    test('a prediction with no runner-up information is not blocked by the gate', () {
      final decoder = SpellDecoder(holdDuration: const Duration(milliseconds: 264));
      String? committed;
      for (var i = 0; i < 30; i++) {
        committed ??= decoder.addPrediction(p('A'), tick()).committedLetter;
      }
      expect(committed, 'A');
    });
  });

  group('transition gating', () {
    test('a moving hand neither advances nor resets the hold', () {
      final decoder = SpellDecoder(holdDuration: const Duration(milliseconds: 264));
      for (var i = 0; i < 4; i++) {
        decoder.addPrediction(p('A'), tick());
      }
      final frozen = decoder.holdProgress;
      for (var i = 0; i < 20; i++) {
        final r = decoder.addPrediction(p('A'), tick(), isTransitioning: true);
        expect(r.committedLetter, isNull, reason: 'must not commit mid-transition');
      }
      expect(decoder.holdProgress, frozen);
      expect(decoder.candidateLabel, 'A');
    });
  });

  group('hold progress', () {
    test('rises from 0 to 1 across the hold and resets after a commit', () {
      final decoder = SpellDecoder(holdDuration: const Duration(milliseconds: 330));
      expect(decoder.holdProgress, 0.0);
      var seenPartial = false;
      for (var i = 0; i < 10; i++) {
        final r = decoder.addPrediction(p('A'), tick());
        if (r.committedLetter != null) {
          expect(decoder.holdProgress, 0.0, reason: 'a fresh hold starts empty');
          expect(seenPartial, isTrue);
          return;
        }
        if (decoder.holdProgress > 0 && decoder.holdProgress < 1) seenPartial = true;
      }
      fail('never committed');
    });
  });
}
