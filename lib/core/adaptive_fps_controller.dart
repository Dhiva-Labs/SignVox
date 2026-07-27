import 'dart:async';

import 'app_settings.dart';
import 'thermal_channel.dart';
import 'vision_controller.dart';

/// PLAN.md §10 P7: lowers camera analysis FPS when the device is running
/// hot, and restores it once it cools — only while
/// `AppSettingsData.adaptiveFpsEnabled` is on. One instance for the app's
/// lifetime (see providers.dart); construction alone starts listening, so it
/// only needs to be read once (e.g. from Translate's bootstrap) to activate.
///
/// Needs a real device to verify: emulators generally report a fixed
/// `THERMAL_STATUS_NONE` forever, so this can only be confirmed to compile,
/// wire up, and not crash here — not to actually react to heat.
class AdaptiveFpsController {
  AdaptiveFpsController({
    required this.visionController,
    required this.settings,
    ThermalChannel? thermalChannel,
  }) {
    _sub = (thermalChannel ?? ThermalChannel()).status.listen(
      _onThermalChanged,
    );
  }

  final VisionController visionController;
  final AppSettings settings;
  StreamSubscription<ThermalStatus>? _sub;

  static const _defaultFps = 30;

  void _onThermalChanged(ThermalStatus status) {
    if (!settings.data.value.adaptiveFpsEnabled) {
      visionController.setAnalysisFps(_defaultFps);
      return;
    }
    final fps = switch (status) {
      ThermalStatus.none || ThermalStatus.light => 30,
      ThermalStatus.moderate => 20,
      ThermalStatus.severe => 15,
      ThermalStatus.critical ||
      ThermalStatus.emergency ||
      ThermalStatus.shutdown => 10,
    };
    visionController.setAnalysisFps(fps);
  }

  void dispose() {
    _sub?.cancel();
  }
}
