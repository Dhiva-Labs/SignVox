import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../core/spell_state.dart';
import '../../theme.dart';

/// Live top-3 candidate row inside the Spell glass panel, with a hold-
/// progress ring on the leading letter (PLAN_V2_RECOGNITION.md R3 step 7).
///
/// Half of "feels reliable" is being able to see the machine thinking. The
/// leading candidate is a solid white puck — the single brightest thing on
/// the panel — with the accent ring filling around it as the hold builds;
/// runners-up are quieter glass circles. While the hand is in transit the
/// whole row dims and a "hold still" hint appears, so a paused ring reads as
/// guidance rather than a bug.
class LetterCandidateBar extends StatelessWidget {
  const LetterCandidateBar({super.key, required this.state});

  final SpellState state;

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.accent;
    final candidates = state.candidates
        .where((c) => c.label != 'none')
        .take(3)
        .toList();
    if (candidates.isEmpty) {
      return SizedBox(
        height: 46,
        child: Row(
          children: [
            Icon(
              CupertinoIcons.hand_raised,
              size: 15,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 7),
            Text(
              'Show your hand to the camera',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 46,
      child: Row(
        children: [
          for (var i = 0; i < candidates.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _CandidateChip(
                label: candidates[i].label,
                confidence: candidates[i].confidence,
                // Only the letter actually accumulating a hold gets the ring —
                // showing progress on a runner-up would imply it is about to
                // commit, which it is not.
                progress: candidates[i].label == state.candidateLabel
                    ? state.holdProgress
                    : 0.0,
                isLeading: i == 0,
                dimmed: state.isTransitioning,
                accent: accent,
              ),
            ),
          if (state.isTransitioning)
            Text(
              'hold still…',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
        ],
      ),
    );
  }
}

class _CandidateChip extends StatelessWidget {
  const _CandidateChip({
    required this.label,
    required this.confidence,
    required this.progress,
    required this.isLeading,
    required this.dimmed,
    required this.accent,
  });

  final String label;
  final double confidence;
  final double progress;
  final bool isLeading;
  final bool dimmed;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final size = isLeading ? 46.0 : 34.0;
    return AnimatedOpacity(
      opacity: dimmed ? 0.45 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: Semantics(
        label: '$label ${(confidence * 100).round()} percent',
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isLeading)
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 3,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Colors.white.withValues(alpha: 0.22),
                    valueColor: AlwaysStoppedAnimation(accent),
                  ),
                ),
              Container(
                width: size - (isLeading ? 9 : 0),
                height: size - (isLeading ? 9 : 0),
                decoration: BoxDecoration(
                  color: isLeading
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: isLeading ? 19 : 15,
                    fontWeight: isLeading ? FontWeight.w700 : FontWeight.w500,
                    color: isLeading ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
