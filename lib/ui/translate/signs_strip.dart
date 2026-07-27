import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/signs_state.dart';
import '../../theme.dart';
import '../widgets/frosted.dart';

/// Floating glass panel for Signs mode: committed words, a gentle inline
/// suggestion when a sign nearly matched ("Did you mean…"), and Clear/Speak.
class SignsStrip extends StatelessWidget {
  const SignsStrip({
    super.key,
    required this.state,
    required this.onSpeakAll,
    required this.onClear,
    required this.onAcceptCandidate,
  });

  final ValueListenable<SignsState> state;
  final VoidCallback onSpeakAll;
  final VoidCallback onClear;
  final VoidCallback onAcceptCandidate;

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.accent;
    return ValueListenableBuilder<SignsState>(
      valueListenable: state,
      builder: (context, s, _) {
        final isEmpty = s.sentence.isEmpty;
        return Frosted(
          radius: 28,
          tint: const Color(0x9912121A),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (s.candidateLabel != null) ...[
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.question_circle,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Did you mean “${s.candidateLabel}”?  ·  ${(s.candidateConfidence * 100).round()}%',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GlassPillButton(
                        label: 'Use',
                        filled: true,
                        fillColor: accent,
                        onPressed: onAcceptCandidate,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  height: 34,
                  child: isEmpty
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Perform a taught sign',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) =>
                              SingleChildScrollView(
                                reverse: true,
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: constraints.maxWidth,
                                  ),
                                  child: Row(
                                    children: [
                                      for (final word in s.sentence)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 10,
                                          ),
                                          child: Text(
                                            word,
                                            style: TextStyle(
                                              fontSize: 21,
                                              fontWeight: FontWeight.w500,
                                              letterSpacing: -0.3,
                                              color: Colors.white.withValues(
                                                alpha: 0.92,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                        ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
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
