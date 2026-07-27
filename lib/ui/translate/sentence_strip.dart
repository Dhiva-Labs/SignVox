import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/spell_state.dart';
import '../../theme.dart';
import '../widgets/frosted.dart';
import 'letter_candidate_bar.dart';

/// The floating glass panel at the bottom of Spell mode: live candidates,
/// the sentence being composed (current word in an accent lozenge), and the
/// action row with one true primary — Speak.
class SentenceStrip extends StatelessWidget {
  const SentenceStrip({
    super.key,
    required this.state,
    required this.onSpeakAll,
    required this.onBackspace,
    required this.onAddSpace,
    required this.onClear,
    this.onSuggestion,
  });

  final ValueListenable<SpellState> state;
  final VoidCallback onSpeakAll;
  final VoidCallback onBackspace;
  final VoidCallback onAddSpace;
  final VoidCallback onClear;

  /// Called with the tapped completion word; null hides the suggestion row.
  final ValueChanged<String>? onSuggestion;

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.accent;
    return ValueListenableBuilder<SpellState>(
      valueListenable: state,
      builder: (context, s, _) {
        final isEmpty = s.sentence.isEmpty && s.currentWord.isEmpty;
        return Frosted(
          radius: 28,
          tint: const Color(0x9912121A),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LetterCandidateBar(state: s),
                if (onSuggestion != null && s.suggestions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _SuggestionRow(words: s.suggestions, onTap: onSuggestion!),
                ],
                const SizedBox(height: 12),
                _SentenceLine(state: s, accent: accent),
                const SizedBox(height: 14),
                Row(
                  children: [
                    GlassIconButton(
                      icon: CupertinoIcons.delete_left,
                      semanticLabel: 'Backspace',
                      fill: Colors.white.withValues(alpha: 0.13),
                      onPressed: isEmpty ? null : onBackspace,
                    ),
                    const SizedBox(width: 10),
                    GlassIconButton(
                      icon: CupertinoIcons.arrow_right_to_line,
                      semanticLabel: 'Add space',
                      fill: Colors.white.withValues(alpha: 0.13),
                      onPressed: s.currentWord.isEmpty ? null : onAddSpace,
                    ),
                    const SizedBox(width: 10),
                    GlassIconButton(
                      icon: CupertinoIcons.trash,
                      semanticLabel: 'Clear',
                      fill: Colors.white.withValues(alpha: 0.13),
                      onPressed: isEmpty ? null : onClear,
                    ),
                    const Spacer(),
                    GlassPillButton(
                      label: 'Speak',
                      icon: CupertinoIcons.speaker_2_fill,
                      onPressed: isEmpty ? null : onSpeakAll,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One-tap word completions — the "finish the word for me" chips that make
/// conversational spelling fast: two letters plus a tap instead of a whole
/// word of holds.
class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.words, required this.onTap});

  final List<String> words;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          for (final word in words.take(3))
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap(word);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    word,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SentenceLine extends StatelessWidget {
  const _SentenceLine({required this.state, required this.accent});

  final SpellState state;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isEmpty = state.sentence.isEmpty && state.currentWord.isEmpty;
    return SizedBox(
      height: 34,
      child: isEmpty
          ? Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Spell a word to begin',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                // Reversed so the newest words stay in view as the line grows;
                // the min-width pin keeps short content left-aligned instead of
                // end-anchored.
                reverse: true,
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Row(
                    children: [
                      for (final word in state.sentence)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Text(
                            word,
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.3,
                              color: Colors.white.withValues(alpha: 0.92),
                            ),
                          ),
                        ),
                      if (state.currentWord.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.32),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            state.currentWord,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
