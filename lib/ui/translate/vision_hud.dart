import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/vision_stats.dart';

/// Small debug capsule showing analysis FPS, last inference time, and hand
/// count — used to verify the smoothness budget in PLAN.md §5.6/§11. Styled
/// as quiet camera chrome so leaving it on doesn't wreck the look.
class VisionHud extends StatelessWidget {
  const VisionHud({super.key, required this.stats});

  final ValueListenable<VisionStats> stats;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VisionStats>(
      valueListenable: stats,
      builder: (context, s, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${s.fps.toStringAsFixed(1)} fps · ${s.lastInferenceMs.toStringAsFixed(0)} ms · '
                  '${s.handCount} hand${s.handCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (s.normalizedIndexTipY != null)
                  Text(
                    // Should hold steady for a held pose regardless of the
                    // hand's distance from the camera (PLAN.md P2 verify step).
                    'norm idx-tip y: ${s.normalizedIndexTipY!.toStringAsFixed(3)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 10,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
