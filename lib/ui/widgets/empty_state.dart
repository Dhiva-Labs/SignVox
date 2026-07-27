import 'package:flutter/material.dart';

import '../../theme.dart';

/// Quiet centered empty state: big tertiary glyph, Title-3 heading, one
/// subheadline of guidance, optionally a single call-to-action.
class SvEmptyState extends StatelessWidget {
  const SvEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.onDark = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  /// True when shown over camera/black instead of the grouped background.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context).textTheme;
    final titleColor = onDark ? Colors.white : colors.label;
    final bodyColor = onDark
        ? Colors.white.withValues(alpha: 0.6)
        : colors.secondaryLabel;
    // Scroll instead of overflowing when the host gives us less height than
    // the content needs (e.g. Conversation mode's split transcript pane).
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = _content(theme, colors, titleColor, bodyColor);
        if (!constraints.hasBoundedHeight) return Center(child: content);
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: content),
          ),
        );
      },
    );
  }

  Widget _content(
    TextTheme theme,
    AppColors colors,
    Color titleColor,
    Color bodyColor,
  ) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 52,
            color: onDark
                ? Colors.white.withValues(alpha: 0.35)
                : colors.tertiaryLabel,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.titleLarge?.copyWith(color: titleColor),
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                message!,
                style: theme.bodyMedium?.copyWith(color: bodyColor),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 24), action!],
        ],
      ),
    );
  }
}
