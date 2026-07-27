import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// SignVox design system — Apple HIG grammar, implemented in Material.
///
/// Everything visual hangs off two things defined here: [AppColors] (the iOS
/// semantic palette — label/secondaryLabel/fill/separator/etc — as a
/// ThemeExtension both modes share) and an SF-Pro-shaped type scale typeset
/// in Inter. Screens must reach for `context.colors.*` rather than raw hex or
/// `colorScheme.*` so light/dark stay in lockstep; the Material ColorScheme
/// is populated only so stock widgets (progress spinners, license page)
/// blend in.

class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.groupedBg,
    required this.card,
    required this.fill,
    required this.label,
    required this.secondaryLabel,
    required this.tertiaryLabel,
    required this.separator,
    required this.accent,
    required this.destructive,
    required this.success,
    required this.warning,
  });

  /// systemBackground — sheets, search fields, the tab bar's frost tint.
  final Color bg;

  /// systemGroupedBackground — every list screen's scaffold.
  final Color groupedBg;

  /// secondarySystemGroupedBackground — the inset rounded cells on top of it.
  final Color card;

  /// The gray fill iOS uses for chips, search fields, segmented tracks.
  final Color fill;

  final Color label;
  final Color secondaryLabel;
  final Color tertiaryLabel;

  /// Hairline color; always draw it 0.5px thick.
  final Color separator;

  final Color accent;
  final Color destructive;
  final Color success;
  final Color warning;

  static const light = AppColors(
    bg: Color(0xFFFFFFFF),
    groupedBg: Color(0xFFF2F2F7),
    card: Color(0xFFFFFFFF),
    fill: Color(0x1F787880),
    label: Color(0xFF000000),
    secondaryLabel: Color(0x993C3C43),
    tertiaryLabel: Color(0x4D3C3C43),
    separator: Color(0x4A3C3C43),
    accent: Color(0xFF007AFF),
    destructive: Color(0xFFFF3B30),
    success: Color(0xFF34C759),
    warning: Color(0xFFFF9500),
  );

  static const dark = AppColors(
    bg: Color(0xFF1C1C1E),
    groupedBg: Color(0xFF000000),
    card: Color(0xFF1C1C1E),
    fill: Color(0x3D787880),
    label: Color(0xFFFFFFFF),
    secondaryLabel: Color(0x99EBEBF5),
    tertiaryLabel: Color(0x4DEBEBF5),
    separator: Color(0x99545458),
    accent: Color(0xFF0A84FF),
    destructive: Color(0xFFFF453A),
    success: Color(0xFF30D158),
    warning: Color(0xFFFF9F0A),
  );

  @override
  AppColors copyWith({
    Color? bg,
    Color? groupedBg,
    Color? card,
    Color? fill,
    Color? label,
    Color? secondaryLabel,
    Color? tertiaryLabel,
    Color? separator,
    Color? accent,
    Color? destructive,
    Color? success,
    Color? warning,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      groupedBg: groupedBg ?? this.groupedBg,
      card: card ?? this.card,
      fill: fill ?? this.fill,
      label: label ?? this.label,
      secondaryLabel: secondaryLabel ?? this.secondaryLabel,
      tertiaryLabel: tertiaryLabel ?? this.tertiaryLabel,
      separator: separator ?? this.separator,
      accent: accent ?? this.accent,
      destructive: destructive ?? this.destructive,
      success: success ?? this.success,
      warning: warning ?? this.warning,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      groupedBg: Color.lerp(groupedBg, other.groupedBg, t)!,
      card: Color.lerp(card, other.card, t)!,
      fill: Color.lerp(fill, other.fill, t)!,
      label: Color.lerp(label, other.label, t)!,
      secondaryLabel: Color.lerp(secondaryLabel, other.secondaryLabel, t)!,
      tertiaryLabel: Color.lerp(tertiaryLabel, other.tertiaryLabel, t)!,
      separator: Color.lerp(separator, other.separator, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  /// Falls back by brightness when the ambient Theme wasn't built by
  /// [buildLightTheme]/[buildDarkTheme] — bare MaterialApps in widget tests
  /// and framework-owned routes like the license page still resolve.
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppColors.dark
          : AppColors.light);
}

/// The iOS Settings icon-badge palette (kept apart from [AppColors] because
/// badges keep their hue in both modes).
abstract final class BadgeColors {
  static const blue = Color(0xFF007AFF);
  static const green = Color(0xFF34C759);
  static const indigo = Color(0xFF5856D6);
  static const orange = Color(0xFFFF9500);
  static const purple = Color(0xFFAF52DE);
  static const red = Color(0xFFFF3B30);
  static const teal = Color(0xFF30B0C7);
  static const yellow = Color(0xFFFFCC00);
  static const gray = Color(0xFF8E8E93);
}

/// SF-Pro's optical sizes, mapped onto Material's TextTheme slots. The
/// negative tracking on the large sizes is what makes Inter read as SF
/// rather than as a web font.
TextTheme _textTheme(AppColors c) {
  TextStyle s(double size, FontWeight w, double spacing, [double? height]) =>
      TextStyle(
        fontSize: size,
        fontWeight: w,
        letterSpacing: spacing,
        height: height,
        color: c.label,
      );
  return TextTheme(
    // Large Title
    displaySmall: s(34, FontWeight.w700, -0.8, 1.18),
    // Title 1
    headlineMedium: s(28, FontWeight.w700, -0.6, 1.2),
    // Title 2
    headlineSmall: s(22, FontWeight.w700, -0.45, 1.22),
    // Title 3
    titleLarge: s(20, FontWeight.w600, -0.35, 1.25),
    // Headline (emphasized body)
    titleMedium: s(17, FontWeight.w600, -0.4, 1.29),
    titleSmall: s(15, FontWeight.w600, -0.2, 1.3),
    // Body
    bodyLarge: s(17, FontWeight.w400, -0.4, 1.29),
    // Subheadline
    bodyMedium: s(15, FontWeight.w400, -0.2, 1.33),
    // Footnote
    bodySmall: s(13, FontWeight.w400, -0.1, 1.38),
    // Buttons
    labelLarge: s(17, FontWeight.w600, -0.4),
    labelMedium: s(13, FontWeight.w500, -0.05),
    // Caption
    labelSmall: s(11, FontWeight.w500, 0.05),
  );
}

ThemeData _build(AppColors c, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final text = _textTheme(c);
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'Inter',
    textTheme: text,
    scaffoldBackgroundColor: c.groupedBg,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: Colors.white,
      secondary: c.accent,
      onSecondary: Colors.white,
      error: c.destructive,
      onError: Colors.white,
      surface: c.card,
      onSurface: c.label,
      surfaceContainerHighest: c.fill,
      onSurfaceVariant: c.secondaryLabel,
      outline: c.separator,
    ),
    // iOS has no ink ripples — presses read as a flat highlight instead.
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: isDark ? const Color(0x29EBEBF5) : const Color(0x14000000),
    dividerTheme: DividerThemeData(
      color: c.separator,
      thickness: 0.33,
      space: 0.33,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      toolbarHeight: 52,
      titleTextStyle: text.titleMedium,
      iconTheme: IconThemeData(color: c.accent, size: 24),
      systemOverlayStyle: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: c.fill,
        disabledForegroundColor: c.tertiaryLabel,
        minimumSize: const Size(44, 50),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: text.labelLarge,
      ),
    ),
    // OutlinedButton is restyled as the iOS "tinted" button — accent text on
    // a translucent accent wash, no outline (used for secondary actions).
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.accent,
        backgroundColor: c.accent.withValues(alpha: isDark ? 0.18 : 0.12),
        disabledForegroundColor: c.tertiaryLabel,
        disabledBackgroundColor: c.fill,
        minimumSize: const Size(44, 50),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.accent,
        textStyle: text.bodyLarge,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.accent,
      linearTrackColor: c.fill,
      circularTrackColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark
          ? const Color(0xFF2C2C2E)
          : const Color(0xFF303034),
      contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.card,
      hintStyle: text.bodyLarge?.copyWith(color: c.tertiaryLabel),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: c.secondaryLabel,
      titleTextStyle: text.bodyLarge,
      subtitleTextStyle: text.bodySmall?.copyWith(color: c.secondaryLabel),
    ),
    // Every route slides in from the right with the edge-swipe back gesture,
    // Android included.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    // Keeps CupertinoSwitch / CupertinoSlider / Cupertino dialogs on-accent.
    cupertinoOverrideTheme: NoDefaultCupertinoThemeData(
      primaryColor: c.accent,
      brightness: brightness,
    ),
    extensions: [c],
  );
}

ThemeData buildLightTheme() => _build(AppColors.light, Brightness.light);

ThemeData buildDarkTheme() => _build(AppColors.dark, Brightness.dark);
