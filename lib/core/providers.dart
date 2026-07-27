import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db.dart';
import '../data/history_repository.dart';
import '../data/sign_repository.dart';
import '../speech/tts_service.dart';
import 'adaptive_fps_controller.dart';
import 'app_settings.dart';
import 'vision_channel.dart';
import 'vision_controller.dart';

/// One [VisionController] for the whole app's lifetime — see the class doc
/// for why this must be shared rather than created per-screen.
final visionControllerProvider = Provider<VisionController>((ref) {
  final controller = VisionController(VisionChannel());
  ref.onDispose(controller.dispose);
  return controller;
});

/// One [AppDatabase]/[SignRepository] for the whole app — Teach, Vocabulary,
/// and Signs mode all read/write the same taught-signs data.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final signRepositoryProvider = Provider<SignRepository>((ref) {
  return SignRepository(ref.watch(databaseProvider));
});

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepository(ref.watch(databaseProvider));
});

/// One [AppSettings] for the whole app (PLAN.md §4 screen 7) — every screen
/// that reads or changes a preference shares the same persisted state.
final appSettingsProvider = Provider<AppSettings>((ref) {
  final settings = AppSettings();
  ref.onDispose(settings.dispose);
  return settings;
});

/// Constructing this starts the thermal listener (PLAN.md §10 P7) — reading
/// it once (Translate's bootstrap does) is enough to activate it for the
/// app's lifetime.
final adaptiveFpsControllerProvider = Provider<AdaptiveFpsController>((ref) {
  final controller = AdaptiveFpsController(
    visionController: ref.watch(visionControllerProvider),
    settings: ref.watch(appSettingsProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

/// One [TtsService] for the whole app — both Spell and Signs mode speak
/// through it, and the bundled neural voice is expensive enough to
/// initialize once (§6.4), not per screen/mode.
final ttsServiceProvider = Provider<TtsService>((ref) {
  final tts = TtsService();
  ref.onDispose(tts.dispose);
  return tts;
});
