import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

/// Absolute on-disk paths sherpa-onnx needs to load the bundled Piper voice
/// — it requires real files, not Flutter asset-bundle handles (PLAN.md §6.4).
class TtsModelPaths {
  const TtsModelPaths({
    required this.modelPath,
    required this.tokensPath,
    required this.dataDirPath,
  });
  final String modelPath;
  final String tokensPath;
  final String dataDirPath;
}

/// Copies the bundled `assets/tts/**` files to disk once, and caches
/// synthesized WAVs by text so repeats (quick-phrases, re-speaking) are
/// instant instead of re-running inference (PLAN.md §6.4).
class TtsCache {
  static const _voiceDir = 'vits-piper-en_US-ljspeech-medium';
  static const _assetPrefix = 'assets/tts/';

  Future<TtsModelPaths> ensureModelFilesOnDisk() async {
    // sherpa_onnx.writeWave() below runs on this (the main/UI) isolate, a
    // separate one from the OfflineTts engine itself (which lives in
    // SherpaTtsIsolate's dedicated background isolate). initBindings() sets
    // up FFI/native-library state that's local to whichever isolate calls
    // it, so it must be called here too, not just inside that isolate —
    // omitting it throws "Please initialize sherpa-onnx first" from
    // writeWave (caught during P4 integration testing).
    sherpa_onnx.initBindings();

    final support = await getApplicationSupportDirectory();
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final ttsAssets = manifest.listAssets().where(
      (a) => a.startsWith(_assetPrefix),
    );

    for (final assetPath in ttsAssets) {
      final relative = assetPath.substring('assets/'.length);
      final target = File(p.join(support.path, relative));
      if (await target.exists()) {
        continue; // copied by a previous run; assets don't change at runtime
      }
      await target.create(recursive: true);
      final data = await rootBundle.load(assetPath);
      await target.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    }

    final voiceDir = p.join(support.path, 'tts', _voiceDir);
    return TtsModelPaths(
      modelPath: p.join(voiceDir, 'en_US-ljspeech-medium.onnx'),
      tokensPath: p.join(voiceDir, 'tokens.txt'),
      dataDirPath: p.join(voiceDir, 'espeak-ng-data'),
    );
  }

  Directory? _cacheDir;

  Future<Directory> _wavCacheDir() async {
    final existing = _cacheDir;
    if (existing != null) return existing;
    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'tts_wav_cache'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return _cacheDir = dir;
  }

  /// Returns a cached WAV path for [text] at [rate] if one already exists,
  /// otherwise synthesizes it via [generate] and writes it to the cache
  /// first. Cached by (text, rate) per PLAN.md §6.4 — the same phrase at a
  /// different speaking rate is a different WAV.
  Future<String> getOrSynthesize(
    String text,
    double rate,
    Future<({Float32List samples, int sampleRate})> Function(
      String text,
      double rate,
    )
    generate,
  ) async {
    final dir = await _wavCacheDir();
    final key = _cacheKey(text, rate);
    final file = File(p.join(dir.path, '$key.wav'));
    if (await file.exists()) return file.path;

    final audio = await generate(text, rate);
    final ok = sherpa_onnx.writeWave(
      filename: file.path,
      samples: audio.samples,
      sampleRate: audio.sampleRate,
    );
    if (!ok) throw StateError('Failed to write synthesized wav for "$text"');
    return file.path;
  }

  String _cacheKey(String text, double rate) {
    // Local, non-security-critical cache key — collisions would at worst
    // replay a different cached phrase, not crash or leak anything.
    return '${text.trim().toLowerCase()}|$rate'.hashCode
        .toRadixString(36)
        .replaceAll('-', 'n');
  }
}
