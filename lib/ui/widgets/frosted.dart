import 'dart:ui';

import 'package:flutter/material.dart';

/// Real frosted glass — blur what's behind, wash it with a translucent tint,
/// edge it with a half-pixel light border so the pane reads as material
/// rather than as a gray rectangle. Reserved for the few large surfaces that
/// earn a BackdropFilter (the tab bar, nav bars, the Translate strip); small
/// controls fake it with a plain scrim, which is indistinguishable at 40 px
/// and much cheaper per frame.
class Frosted extends StatelessWidget {
  const Frosted({
    super.key,
    required this.child,
    this.radius = 24,
    this.tint = const Color(0x8C17171A),
    this.blur = 24,
    this.hairline = true,
  });

  final Widget child;
  final double radius;
  final Color tint;
  final double blur;
  final bool hairline;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tint,
            borderRadius: shape,
            border: hairline
                ? Border.all(color: const Color(0x14FFFFFF), width: 0.5)
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Circular scrim button for camera chrome (no blur — see [Frosted]).
/// White glyph on dark glass; [active] inverts to a solid white puck the way
/// iOS Camera marks an engaged control. Presses dip to 88% scale.
class GlassIconButton extends StatefulWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.onPressed,
    this.active = false,
    this.size = 42,
    this.iconSize = 20,
    this.fill,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final bool active;
  final double size;
  final double iconSize;

  /// Overrides the default dark scrim — e.g. a white wash when the button
  /// already sits on a dark glass panel.
  final Color? fill;

  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton> {
  bool _pressed = false;

  Color _scrim(bool enabled) {
    final base = widget.fill ?? Colors.black.withValues(alpha: 0.42);
    return enabled ? base : base.withValues(alpha: base.a * 0.6);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.88 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.active ? Colors.white : _scrim(enabled),
            ),
            child: Icon(
              widget.icon,
              size: widget.iconSize,
              color: widget.active
                  ? Colors.black
                  : Colors.white.withValues(alpha: enabled ? 1.0 : 0.4),
            ),
          ),
        ),
      ),
    );
  }
}

/// Capsule action button for dark camera chrome: [filled] is the one accent
/// primary (Speak); unfilled is a neutral glass capsule.
class GlassPillButton extends StatelessWidget {
  const GlassPillButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.filled = true,
    this.fillColor,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool filled;
  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final bg = !enabled
        ? Colors.white.withValues(alpha: 0.12)
        : filled
        ? (fillColor ?? Theme.of(context).colorScheme.primary)
        : Colors.white.withValues(alpha: 0.16);
    final fg = enabled ? Colors.white : Colors.white.withValues(alpha: 0.35);
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(21),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: fg),
                const SizedBox(width: 7),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
