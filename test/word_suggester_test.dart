import 'package:flutter_test/flutter_test.dart';
import 'package:sign_vox/engines/word_suggester.dart';

void main() {
  // Frequency order: earlier = more common, exactly like the bundled asset.
  final suggester = WordSuggester.fromWords([
    'YOU', 'THE', 'TO', 'THAT', 'HELLO', 'HELP', 'HELMET', 'HE', 'THANKS',
  ]);

  group('WordSuggester', () {
    test('completions come back most-frequent first', () {
      expect(suggester.suggest('TH'), ['THE', 'THAT', 'THANKS']);
    });

    test('the already-typed word itself is never suggested', () {
      expect(suggester.suggest('HE'), isNot(contains('HE')));
      expect(suggester.suggest('HE'), ['HELLO', 'HELP', 'HELMET']);
    });

    test('respects max and prefix boundaries exactly', () {
      expect(suggester.suggest('HEL', max: 2), ['HELLO', 'HELP']);
      // 'HELLOX' matches nothing; 'T' alone spans THE/TO/THAT/THANKS.
      expect(suggester.suggest('HELLOX'), isEmpty);
      expect(suggester.suggest('T'), ['THE', 'TO', 'THAT']);
    });

    test('empty prefix suggests nothing (no noise before the first letter)', () {
      expect(suggester.suggest(''), isEmpty);
    });

    test('lower-case input matches the upper-case list', () {
      expect(suggester.suggest('yo'), ['YOU']);
    });
  });

  group('WordSuggester.correct', () {
    test('one substituted letter is repaired to the frequent word', () {
      expect(suggester.correct('HELLN'), 'HELLO');
      expect(suggester.correct('TXANKS'), 'THANKS');
    });

    test('adjacent transposition is repaired', () {
      expect(suggester.correct('TAHT'), 'THAT');
    });

    test('one missing or extra letter is repaired', () {
      expect(suggester.correct('HLLO'), 'HELLO'); // deletion
      expect(suggester.correct('HELLLO'), 'HELLO'); // insertion
    });

    test('known words are never "corrected"', () {
      expect(suggester.correct('HELLO'), isNull);
      expect(suggester.correct('THANKS'), isNull);
    });

    test('short words and far-off gibberish are left alone', () {
      expect(suggester.correct('HE'), isNull); // too short to judge
      expect(suggester.correct('XQZV'), isNull); // nothing within one edit
    });

    test('ties resolve to the most frequent candidate', () {
      // 'THT' is one edit from both THAT and THE... THE wins on rank.
      expect(suggester.correct('THT'), 'THE');
    });
  });
}
