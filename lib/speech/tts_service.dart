import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';

import 'sherpa_tts_isolate.dart';
import 'tts_cache.dart';

/// Spell-mode voice output (PLAN.md §6.4): bundled neural (Piper/sherpa-onnx)
/// voice as the primary path, each word appended to the player's own
/// playlist so speaking overlaps continued signing with no gap between
/// words. Falls back to the Android system TTS (`flutter_tts`) both while
/// the neural voice is still loading and if it ever fails to initialize —
/// callers never need to know which is active.
class TtsService {
  TtsService() {
    _readyFuture = _initialize();
  }

  final _cache = TtsCache();
  final _fallback = FlutterTts();
  final _player = AudioPlayer();
  SherpaTtsIsolate? _sherpa;
  bool _sherpaReady = false;
  late final Future<void> _readyFuture;
  double _rate = 1.0;

  /// Completes once init has been attempted (success or fallback) — for a
  /// "voice loading" UI state (PLAN.md §6.4) and for tests that need to
  /// wait past the async neural-voice startup before calling [speak].
  Future<void> get ready => _readyFuture;

  /// Whether the neural voice is active (false means every [speak] call is
  /// going through the flutter_tts fallback instead).
  bool get isNeuralVoiceReady => _sherpaReady;

  /// Speaking rate (1.0 = normal), applied to both the neural voice and the
  /// flutter_tts fallback. PLAN.md §6.4/§4 screen 7 settings.
  Future<void> setRate(double rate) async {
    _rate = rate;
    await _fallback.setSpeechRate(rate);
  }

  Future<void> _initialize() async {
    try {
      final paths = await _cache.ensureModelFilesOnDisk();
      _sherpa = await SherpaTtsIsolate.spawn(
        modelPath: paths.modelPath,
        tokensPath: paths.tokensPath,
        dataDirPath: paths.dataDirPath,
      );
      await _player.setAudioSources(const []);
      _sherpaReady = true;
    } catch (e, st) {
      // speak() already falls back to flutter_tts whenever _sherpaReady is
      // false, which covers both "still loading" and "failed" uniformly —
      // but still log the real cause (P1 lesson: a silent catch here cost
      // real debugging time once already, see PLAN.md's P1 gotchas).
      debugPrint(
        'TtsService: sherpa-onnx init failed, falling back to flutter_tts: $e\n$st',
      );
      _sherpaReady = false;
    }
  }

  Future<void> speak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    if (!_sherpaReady) {
      await _fallback.speak(trimmed);
      return;
    }

    try {
      final wavPath = await _cache.getOrSynthesize(
        trimmed,
        _rate,
        (t, r) => _sherpa!.generate(t, speed: r),
      );
      await _player.addAudioSource(AudioSource.uri(Uri.file(wavPath)));
      // just_audio's play() future only resolves once the playlist drains,
      // so it must never be awaited here — that would block every caller of
      // speak() until all speech finished, defeating the whole point of an
      // incremental queue that keeps up with continued signing.
      if (!_player.playing) {
        unawaited(_player.play());
      }
    } catch (e) {
      debugPrint(
        'TtsService: sherpa-onnx speak("$trimmed") failed, falling back to flutter_tts: $e',
      );
      await _fallback.speak(trimmed);
    }
  }

  Future<void> stop() async {
    await _player.stop();
    await _fallback.stop();
  }

  Future<void> dispose() async {
    await _player.dispose();
    await _fallback.stop();
    _sherpa?.dispose();
  }
}
