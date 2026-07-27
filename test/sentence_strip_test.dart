import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sign_vox/core/spell_state.dart';
import 'package:sign_vox/theme.dart';
import 'package:sign_vox/ui/translate/sentence_strip.dart';

void main() {
  SpellState midWord({List<String> suggestions = const []}) => SpellState(
    sentence: const ['HI'],
    currentWord: 'HE',
    candidates: const [LetterCandidate('E', 0.92)],
    suggestions: suggestions,
  );

  Widget host(ValueListenable<SpellState> state, {ValueChanged<String>? onSuggestion}) {
    return MaterialApp(
      theme: buildLightTheme(),
      home: Scaffold(
        body: SentenceStrip(
          state: state,
          onSpeakAll: () {},
          onBackspace: () {},
          onAddSpace: () {},
          onClear: () {},
          onSuggestion: onSuggestion,
        ),
      ),
    );
  }

  testWidgets('suggestion chips render and tapping one reports the word', (tester) async {
    final state = ValueNotifier(
      midWord(suggestions: const ['HELLO', 'HELP', 'HELMET']),
    );
    String? tapped;
    await tester.pumpWidget(host(state, onSuggestion: (w) => tapped = w));

    expect(find.text('HELLO'), findsOneWidget);
    expect(find.text('HELP'), findsOneWidget);
    expect(find.text('HELMET'), findsOneWidget);

    await tester.tap(find.text('HELLO'));
    expect(tapped, 'HELLO');
  });

  testWidgets('no suggestion row when there are no completions', (tester) async {
    final state = ValueNotifier(midWord());
    await tester.pumpWidget(host(state, onSuggestion: (_) {}));
    expect(find.text('HELLO'), findsNothing);
    // The rest of the strip still renders.
    expect(find.text('Speak'), findsOneWidget);
  });

  testWidgets('no suggestion row when the callback is absent', (tester) async {
    final state = ValueNotifier(
      midWord(suggestions: const ['HELLO', 'HELP', 'HELMET']),
    );
    await tester.pumpWidget(host(state));
    expect(find.text('HELLO'), findsNothing);
  });
}
