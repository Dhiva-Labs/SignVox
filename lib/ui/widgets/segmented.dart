import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme.dart';

/// iOS 13-style segmented control: a gray track, a sliding white thumb with
/// a soft shadow, 13pt labels that go semibold when selected, a selection
/// haptic on change. [onDark] renders the camera-chrome variant (dark glass
/// track, white thumb, black selected label).
class SvSegmented<T> extends StatelessWidget {
  const SvSegmented({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.onDark = false,
    this.height = 32,
  });

  final List<(T, String)> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final bool onDark;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final n = segments.length;
    var index = segments.indexWhere((s) => s.$1 == value);
    if (index < 0) index = 0;

    final track = onDark ? Colors.black.withValues(alpha: 0.4) : colors.fill;
    final thumb = onDark
        ? Colors.white
        : isDarkTheme
        ? const Color(0xFF636366)
        : Colors.white;

    return Container(
      height: height,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: n == 1
                ? Alignment.center
                : Alignment(-1 + 2 * index / (n - 1), 0),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: FractionallySizedBox(
              widthFactor: 1 / n,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: thumb,
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final (i, segment) in segments.indexed)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (segment.$1 == value) return;
                      HapticFeedback.selectionClick();
                      onChanged(segment.$1);
                    },
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 150),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          letterSpacing: -0.1,
                          fontWeight: i == index
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: onDark
                              ? (i == index ? Colors.black : Colors.white)
                              : colors.label,
                        ),
                        child: Text(segment.$2, maxLines: 1),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
