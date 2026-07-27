import 'package:flutter_test/flutter_test.dart';
import 'package:sign_vox/engines/decoder.dart';
import 'package:sign_vox/engines/letter_engine.dart';

void main() {
  group('SpellDecoder', () {
    late DateTime now;
    setUp(() => now = DateTime(2026, 1, 1));

    DateTime tick([int ms = 33]) => now = now.add(Duration(milliseconds: ms));

    test('commits a letter only once holdFrames stable high-confidence frames pass', () {
      final decoder = SpellDecoder(holdFrames: 8);
      const pred = LetterPrediction(label: 'A', confidence: 0.95);

      for (var i = 0; i < 7; i++) {
        final r = decoder.addPrediction(pred, tick());
        expect(r.committedLetter, isNull, reason: 'frame $i should not commit yet');
      }
      final r = decoder.addPrediction(pred, tick());
      expect(r.committedLetter, 'A');
      expect(decoder.currentWord, 'A');
    });

    test('does not commit below commitConfidence even when stable', () {
      final decoder = SpellDecoder(holdFrames: 8, commitConfidence: 0.8);
      const pred = LetterPrediction(label: 'A', confidence: 0.6);

      for (var i = 0; i < 20; i++) {
        final r = decoder.addPrediction(pred, tick());
        expect(r.committedLetter, isNull);
      }
      expect(decoder.currentWord, isEmpty);
    });

    test('resets stability progress when the predicted label changes', () {
      final decoder = SpellDecoder(holdFrames: 8);
      for (var i = 0; i < 6; i++) {
        decoder.addPrediction(const LetterPrediction(label: 'A', confidence: 0.95), tick());
      }
      // Switch labels before reaching holdFrames — progress should not carry over.
      for (var i = 0; i < 7; i++) {
        final r = decoder.addPrediction(const LetterPrediction(label: 'B', confidence: 0.95), tick());
        expect(r.committedLetter, isNull, reason: 'B has only had $i/8 stable frames so far');
      }
      final r = decoder.addPrediction(const LetterPrediction(label: 'B', confidence: 0.95), tick());
      expect(r.committedLetter, 'B');
    });

    test('resets stability on a none prediction', () {
      final decoder = SpellDecoder(holdFrames: 8);
      for (var i = 0; i < 6; i++) {
        decoder.addPrediction(const LetterPrediction(label: 'A', confidence: 0.95), tick());
      }
      decoder.addPrediction(const LetterPrediction(label: 'none', confidence: 0.95), tick());
      for (var i = 0; i < 7; i++) {
        final r = decoder.addPrediction(const LetterPrediction(label: 'A', confidence: 0.95), tick());
        expect(r.committedLetter, isNull);
      }
    });

    test('enforces a cooldown immediately after a commit', () {
      final decoder = SpellDecoder(holdFrames: 3, cooldown: const Duration(milliseconds: 300));
      const pred = LetterPrediction(label: 'A', confidence: 0.95);
      for (var i = 0; i < 3; i++) {
        decoder.addPrediction(pred, tick());
      }
      expect(decoder.currentWord, 'A');
      // Still within the 300ms cooldown window (a handful of 33ms ticks).
      for (var i = 0; i < 5; i++) {
        final r = decoder.addPrediction(pred, tick());
        expect(r.committedLetter, isNull);
      }
    });

    test('blocks an immediate same-letter re-commit until confidence dips (the double-letter rule)', () {
      final decoder = SpellDecoder(
        holdFrames: 3,
        cooldown: const Duration(milliseconds: 100),
        recommitConfidence: 0.5,
      );
      const highConf = LetterPrediction(label: 'L', confidence: 0.95);

      for (var i = 0; i < 3; i++) {
        decoder.addPrediction(highConf, tick());
      }
      expect(decoder.currentWord, 'L');

      // Clear the cooldown, but confidence has stayed high throughout —
      // holding the same shape should not spam-commit a second "L".
      while (now.isBefore(DateTime(2026, 1, 1).add(const Duration(milliseconds: 500)))) {
        final r = decoder.addPrediction(highConf, tick());
        expect(r.committedLetter, isNull);
      }
      expect(decoder.currentWord, 'L');

      // A genuine dip (relaxing the hand) between the two L's re-arms it.
      decoder.addPrediction(const LetterPrediction(label: 'L', confidence: 0.3), tick());
      for (var i = 0; i < 3; i++) {
        decoder.addPrediction(highConf, tick());
      }
      expect(decoder.currentWord, 'LL');
    });

    test(
      'a genuinely different letter commits immediately after a prior commit, '
      'with no confidence dip required (regression: this must not reuse the '
      'double-letter gate)',
      () {
        final decoder = SpellDecoder(holdFrames: 3, cooldown: const Duration(milliseconds: 100));
        for (var i = 0; i < 3; i++) {
          decoder.addPrediction(const LetterPrediction(label: 'H', confidence: 0.95), tick());
        }
        expect(decoder.currentWord, 'H');

        // Clear cooldown with a couple of idle ticks, then go straight into a
        // different letter at consistently high confidence — never dipping.
        tick(150);
        for (var i = 0; i < 2; i++) {
          decoder.addPrediction(const LetterPrediction(label: 'E', confidence: 0.95), tick());
        }
        final r = decoder.addPrediction(const LetterPrediction(label: 'E', confidence: 0.95), tick());
        expect(r.committedLetter, 'E');
        expect(decoder.currentWord, 'HE');
      },
    );

    test('commits the current word after a sustained pause and clears the buffer', () {
      final decoder = SpellDecoder(
        holdFrames: 3,
        cooldown: const Duration(milliseconds: 50),
        wordCommitPause: const Duration(seconds: 1),
      );
      for (var i = 0; i < 3; i++) {
        decoder.addPrediction(const LetterPrediction(label: 'H', confidence: 0.95), tick());
      }
      tick(150); // clear the (short, explicit) cooldown before starting the next letter
      for (var i = 0; i < 3; i++) {
        decoder.addPrediction(const LetterPrediction(label: 'I', confidence: 0.95), tick());
      }
      expect(decoder.currentWord, 'HI');

      SpellDecoderResult? withWord;
      final pauseDeadline = now.add(const Duration(seconds: 2));
      while (now.isBefore(pauseDeadline)) {
        final r = decoder.addPrediction(null, tick(100));
        if (r.committedWord != null) withWord = r;
      }
      expect(withWord?.committedWord, 'HI');
      expect(decoder.currentWord, isEmpty);
    });

    test('does not fire a word commit on a pause when nothing has been typed', () {
      final decoder = SpellDecoder(wordCommitPause: const Duration(seconds: 1));
      final deadline = now.add(const Duration(seconds: 2));
      while (now.isBefore(deadline)) {
        final r = decoder.addPrediction(null, tick(100));
        expect(r.committedWord, isNull);
      }
    });
  });
}
