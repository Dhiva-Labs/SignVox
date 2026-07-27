import 'package:flutter/services.dart';

/// Thin wrapper for `signvox/stt` (native side: `MainActivity.isOnDeviceSttAvailable`).
///
/// This is a genuine capability check, not a hint — [SttService] must call
/// it before ever starting a listening session and must not listen at all
/// if it returns false. See `SttService` doc for why.
class SttChannel {
  static const _channel = MethodChannel('signvox/stt');

  Future<bool> isOnDeviceAvailable() async {
    final result = await _channel.invokeMethod<bool>('isOnDeviceAvailable');
    return result ?? false;
  }
}
