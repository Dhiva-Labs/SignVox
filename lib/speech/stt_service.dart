import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../core/stt_channel.dart';

enum SttAvailability { unknown, available, unavailable }

/// Reply-mode live transcript for Conversation mode (PLAN.md §4/§6.5):
/// continuous on-device speech recognition, restarted automatically when the
/// underlying platform session times out, so the transcript keeps flowing
/// without the user re-tapping anything.
///
/// On-device recognition ONLY — never silently falls back to a
/// network-backed recognizer. `speech_to_text`'s own `onDevice` flag does
/// exactly that when on-device support isn't there (confirmed by reading its
/// Kotlin source: it falls through to `createSpeechRecognizer`, which is
/// Google-cloud-eligible and is proxied through a separate system process
/// with its own INTERNET permission — this app declaring none does not
/// block it). [ensureAvailable] checks real on-device support itself, via
/// `signvox/stt` (a one-line native call to
/// `SpeechRecognizer.isOnDeviceRecognitionAvailable`), and this service never
/// calls `listen()` at all unless that check passed — so that fallback path
/// is never reached in practice.
class SttService {
  final _speech = SpeechToText();
  final _channel = SttChannel();

  final ValueNotifier<SttAvailability> availability = ValueNotifier(
    SttAvailability.unknown,
  );
  final ValueNotifier<String> transcript = ValueNotifier('');
  final ValueNotifier<bool> isListening = ValueNotifier(false);

  bool _sessionWanted = false;
  bool _disposed = false;
  int _consecutiveQuickFailures = 0;
  DateTime? _lastListenStart;

  Future<bool> ensureAvailable() async {
    if (availability.value != SttAvailability.unknown) {
      return availability.value == SttAvailability.available;
    }
    final onDevice = await _channel.isOnDeviceAvailable();
    if (!onDevice) {
      availability.value = SttAvailability.unavailable;
      return false;
    }
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      availability.value = SttAvailability.unavailable;
      return false;
    }
    final initialized = await _speech.initialize(
      onError: (e) =>
          debugPrint('SttService: ${e.errorMsg} (permanent=${e.permanent})'),
      onStatus: _onStatus,
    );
    availability.value = initialized
        ? SttAvailability.available
        : SttAvailability.unavailable;
    return initialized;
  }

  /// Starts (or resumes) a continuous listening session. No-op if on-device
  /// recognition isn't available — check [availability] to show an
  /// explainer instead of a silently-dead transcript.
  Future<void> start() async {
    if (!await ensureAvailable()) return;
    _sessionWanted = true;
    _consecutiveQuickFailures = 0;
    await _listenOnce();
  }

  Future<void> stop() async {
    _sessionWanted = false;
    isListening.value = false;
    await _speech.stop();
  }

  Future<void> _listenOnce() async {
    if (!_sessionWanted || _disposed) return;
    _lastListenStart = DateTime.now();
    isListening.value = true;
    await _speech.listen(
      onResult: (result) => transcript.value = result.recognizedWords,
      listenOptions: SpeechListenOptions(
        onDevice: true,
        partialResults: true,
        listenMode: ListenMode.dictation,
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 30),
      ),
    );
  }

  void _onStatus(String status) {
    isListening.value = _speech.isListening;
    if (_speech.isListening || !_sessionWanted || _disposed) return;

    // Restart-on-timeout (§6.5). Guard against a tight restart loop if the
    // platform session is failing instantly (e.g. mic held by another app)
    // rather than genuinely timing out — three quick deaths in a row and we
    // give up instead of spinning forever.
    final start = _lastListenStart;
    final diedQuickly =
        start != null &&
        DateTime.now().difference(start) < const Duration(seconds: 1);
    if (diedQuickly) {
      _consecutiveQuickFailures++;
      if (_consecutiveQuickFailures >= 3) {
        _sessionWanted = false;
        availability.value = SttAvailability.unavailable;
        return;
      }
    } else {
      _consecutiveQuickFailures = 0;
    }
    unawaited(Future.delayed(const Duration(milliseconds: 300), _listenOnce));
  }

  void clearTranscript() => transcript.value = '';

  void dispose() {
    _disposed = true;
    _sessionWanted = false;
    unawaited(_speech.stop());
    availability.dispose();
    transcript.dispose();
    isListening.dispose();
  }
}
