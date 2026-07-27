import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sign_vox/speech/tts_service.dart';

/// Runs on a real device/emulator (`flutter test integration_test/`), not
/// the host-based `flutter test` runner — TtsService needs real native
/// libraries, a real filesystem, and real asset-bundle access that a plain
/// widget test can't provide. This is the only way to verify the actual
/// neural-voice synthesis path PLAN.md P4 hinges on, given this environment
/// has no real camera to drive Spell mode's UI end-to-end.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TtsService initializes the neural voice and synthesizes real audio', (tester) async {
    final tts = TtsService();
    await tts.ready.timeout(
      const Duration(seconds: 30),
      onTimeout: () => fail('TtsService.ready did not complete within 30s'),
    );

    expect(
      tts.isNeuralVoiceReady,
      isTrue,
      reason: 'sherpa-onnx should initialize successfully on a real Android runtime '
          '(see TtsService debug logs if this fails — the init failure is logged, not swallowed)',
    );

    final cacheDir = Directory(p.join((await getTemporaryDirectory()).path, 'tts_wav_cache'));
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true); // start from a clean cache for this check
    }

    await tts.speak('hello world');
    // speak() doesn't await playback (by design — see TtsService docs), but
    // synthesis + wav-write happen before playback starts, so give that a
    // moment to land before checking the cache.
    await Future<void>.delayed(const Duration(seconds: 5));

    expect(await cacheDir.exists(), isTrue, reason: 'speak() should have synthesized and cached a wav file');
    final wavFiles = await cacheDir.list().where((f) => f.path.endsWith('.wav')).toList();
    expect(wavFiles, isNotEmpty, reason: 'no .wav file was written for the spoken text');
    final size = await File(wavFiles.first.path).length();
    expect(size, greaterThan(1000), reason: 'synthesized wav file is suspiciously small: $size bytes');

    await tts.dispose();
  });
}
