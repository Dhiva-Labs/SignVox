import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/landmark_frame.dart';
import '../../core/vision_channel.dart';
import '../../theme.dart';
import '../translate/hand_overlay_painter.dart';

/// Big animated countdown numeral over a capture surface.
class CountdownOverlay extends StatelessWidget {
  const CountdownOverlay(this.value, {super.key});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutBack,
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: Tween(begin: 1.4, end: 1.0).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Text(
          '$value',
          key: ValueKey(value),
          style: const TextStyle(
            fontSize: 88,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            shadows: [Shadow(color: Color(0x73000000), blurRadius: 24)],
          ),
        ),
      ),
    );
  }
}

/// Horizontal letter picker used by Data Lab and Improve Recognition:
/// circular tokens, the selected one solid accent, letters with recorded
/// samples wearing a small green check badge.
class LetterPickerRow extends StatelessWidget {
  const LetterPickerRow({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
    this.countFor,
  });

  final List<String> labels;
  final String selected;
  final ValueChanged<String> onSelected;
  final bool enabled;
  final int Function(String label)? countFor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: 66,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        itemCount: labels.length,
        itemBuilder: (context, i) {
          final label = labels[i];
          final isSelected = label == selected;
          final count = countFor?.call(label) ?? 0;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: enabled ? () => onSelected(label) : null,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 44,
                    constraints: const BoxConstraints(minWidth: 44),
                    padding: EdgeInsets.symmetric(
                      horizontal: label.length > 1 ? 14 : 0,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? colors.accent : colors.fill,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: label.length > 1 ? 15 : 17,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : colors.label.withValues(alpha: enabled ? 1 : 0.4),
                      ),
                    ),
                  ),
                  if (count > 0)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 15,
                        height: 15,
                        decoration: BoxDecoration(
                          color: colors.success,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colors.groupedBg,
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 9,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The rounded capture viewport: camera texture (or black, for skeleton-only
/// capture), hand overlay, optional countdown — clipped to a soft 24pt
/// rounded rectangle like a FaceTime tile.
class CaptureCameraBox extends StatelessWidget {
  const CaptureCameraBox({
    super.key,
    required this.init,
    required this.frame,
    this.showTexture = true,
    this.countdown,
  });

  final CameraInit init;
  final ValueListenable<LandmarkFrame?> frame;
  final bool showTexture;
  final int? countdown;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: init.displayWidth / init.displayHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (showTexture)
              RotatedBox(
                quarterTurns: init.rotationDegrees ~/ 90,
                child: Texture(textureId: init.textureId),
              )
            else
              const ColoredBox(color: Color(0xFF101014)),
            CustomPaint(painter: HandOverlayPainter(frame)),
            if (countdown != null) CountdownOverlay(countdown!),
          ],
        ),
      ),
    );
  }
}
