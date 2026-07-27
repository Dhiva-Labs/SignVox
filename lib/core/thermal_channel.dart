import 'package:flutter/services.dart';

/// Matches Android's `PowerManager.THERMAL_STATUS_*` constants.
enum ThermalStatus {
  none,
  light,
  moderate,
  severe,
  critical,
  emergency,
  shutdown,
}

ThermalStatus _fromAndroid(int value) {
  return ThermalStatus.values.length > value && value >= 0
      ? ThermalStatus.values[value]
      : ThermalStatus.none;
}

/// Wraps `signvox/thermal` (native: `PowerManager.addThermalStatusListener`,
/// API 29+). On older Android or if the OS never calls back, this stream
/// simply never emits — callers should treat "no event yet" as "assume
/// normal," not as an error.
class ThermalChannel {
  static const _events = EventChannel('signvox/thermal');

  Stream<ThermalStatus>? _stream;

  Stream<ThermalStatus> get status {
    return _stream ??= _events.receiveBroadcastStream().map(
      (event) => _fromAndroid(event as int),
    );
  }
}
