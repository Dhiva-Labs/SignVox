import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engines/decoder.dart';

/// Every user-adjustable preference from PLAN.md §4 screen 7 in one place.
@immutable
class AppSettingsData {
  const AppSettingsData({
    required this.themeMode,
    required this.ttsRate,
    required this.speakPerWord,
    required this.letterHoldMs,
    required this.leftHandedMode,
    required this.adaptiveFpsEnabled,
    required this.keepScreenOnWhileTranslating,
    required this.showOverlayByDefault,
    required this.personalisationEnabled,
  });

  final ThemeMode themeMode;

  /// sherpa-onnx's `speed` multiplier (1.0 = normal, >1 faster, <1 slower).
  final double ttsRate;

  /// true (default): each committed word/sign speaks immediately, same as
  /// P3-P6 behavior. false: nothing auto-speaks — only Speak-all does,
  /// giving one clean sentence-level utterance instead of a running commentary.
  final bool speakPerWord;

  /// SpellDecoder.holdDuration in milliseconds — how long a letter must be
  /// held before it commits. Lower = faster but twitchier; higher = steadier
  /// but slower.
  ///
  /// v1.1 changed this from a frame count to a duration
  /// (PLAN_V2_RECOGNITION.md R3 step 2): effective FPS varies 7-30 across
  /// devices and thermal states, so a frame count meant a wildly different hold
  /// time on different phones — and on the *same* phone once it got warm.
  /// Settings persisted before v1.1 are migrated in [fromJson] by multiplying
  /// the stored frame count by [SpellDecoder.msPerFrameEstimate], so an
  /// existing user's slider position keeps the feel they had chosen.
  final int letterHoldMs;

  /// PLAN.md §5.2: flips which tracked hand is treated as dominant.
  final bool leftHandedMode;

  final bool adaptiveFpsEnabled;

  /// Independent of Conversation mode's always-on wakelock (PLAN.md §10 P6) —
  /// this keeps the screen on while actively using Translate too, if enabled.
  final bool keepScreenOnWhileTranslating;

  final bool showOverlayByDefault;

  /// On-device personalisation (PLAN_V2_RECOGNITION.md R6). Nothing is sent
  /// anywhere either way — this only decides whether the user's own captured
  /// prototypes are blended into the letter model's predictions.
  final bool personalisationEnabled;

  static const defaults = AppSettingsData(
    themeMode: ThemeMode.system,
    ttsRate: 1.0,
    speakPerWord: true,
    letterHoldMs: 350,
    leftHandedMode: false,
    adaptiveFpsEnabled: true,
    keepScreenOnWhileTranslating: false,
    showOverlayByDefault: true,
    personalisationEnabled: true,
  );

  AppSettingsData copyWith({
    ThemeMode? themeMode,
    double? ttsRate,
    bool? speakPerWord,
    int? letterHoldMs,
    bool? leftHandedMode,
    bool? adaptiveFpsEnabled,
    bool? keepScreenOnWhileTranslating,
    bool? showOverlayByDefault,
    bool? personalisationEnabled,
  }) {
    return AppSettingsData(
      themeMode: themeMode ?? this.themeMode,
      ttsRate: ttsRate ?? this.ttsRate,
      speakPerWord: speakPerWord ?? this.speakPerWord,
      letterHoldMs: letterHoldMs ?? this.letterHoldMs,
      leftHandedMode: leftHandedMode ?? this.leftHandedMode,
      adaptiveFpsEnabled: adaptiveFpsEnabled ?? this.adaptiveFpsEnabled,
      keepScreenOnWhileTranslating:
          keepScreenOnWhileTranslating ?? this.keepScreenOnWhileTranslating,
      showOverlayByDefault: showOverlayByDefault ?? this.showOverlayByDefault,
      personalisationEnabled:
          personalisationEnabled ?? this.personalisationEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'themeMode': themeMode.name,
    'ttsRate': ttsRate,
    'speakPerWord': speakPerWord,
    'letterHoldMs': letterHoldMs,
    'leftHandedMode': leftHandedMode,
    'adaptiveFpsEnabled': adaptiveFpsEnabled,
    'keepScreenOnWhileTranslating': keepScreenOnWhileTranslating,
    'showOverlayByDefault': showOverlayByDefault,
    'personalisationEnabled': personalisationEnabled,
  };

  factory AppSettingsData.fromJson(Map<String, dynamic> json) {
    final d = defaults;
    return AppSettingsData(
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == json['themeMode'],
        orElse: () => d.themeMode,
      ),
      ttsRate: (json['ttsRate'] as num?)?.toDouble() ?? d.ttsRate,
      speakPerWord: json['speakPerWord'] as bool? ?? d.speakPerWord,
      letterHoldMs:
          json['letterHoldMs'] as int? ??
          // Pre-v1.1 settings stored a frame count; convert rather than reset.
          (json['letterHoldFrames'] is int
              ? (json['letterHoldFrames'] as int) *
                    SpellDecoder.msPerFrameEstimate
              : d.letterHoldMs),
      leftHandedMode: json['leftHandedMode'] as bool? ?? d.leftHandedMode,
      adaptiveFpsEnabled:
          json['adaptiveFpsEnabled'] as bool? ?? d.adaptiveFpsEnabled,
      keepScreenOnWhileTranslating:
          json['keepScreenOnWhileTranslating'] as bool? ??
          d.keepScreenOnWhileTranslating,
      showOverlayByDefault:
          json['showOverlayByDefault'] as bool? ?? d.showOverlayByDefault,
      personalisationEnabled:
          json['personalisationEnabled'] as bool? ?? d.personalisationEnabled,
    );
  }
}

/// Loads/persists [AppSettingsData] via shared_preferences. One instance for
/// the whole app (see providers.dart) — every screen that reads or changes a
/// setting shares the same [data] notifier.
class AppSettings {
  AppSettings() {
    _readyFuture = _load();
  }

  static const _key = 'app_settings_v1';

  final ValueNotifier<AppSettingsData> data = ValueNotifier(
    AppSettingsData.defaults,
  );
  late final Future<void> _readyFuture;

  Future<void> get ready => _readyFuture;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        data.value = AppSettingsData.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
    } catch (e) {
      debugPrint(
        'AppSettings: failed to load persisted settings, using defaults: $e',
      );
    }
  }

  Future<void> update(
    AppSettingsData Function(AppSettingsData current) transform,
  ) async {
    data.value = transform(data.value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data.value.toJson()));
  }

  void dispose() {
    data.dispose();
  }
}
