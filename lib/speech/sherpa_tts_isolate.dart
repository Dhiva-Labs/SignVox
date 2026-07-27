import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

class _InitRequest {
  const _InitRequest({
    required this.rootIsolateToken,
    required this.modelPath,
    required this.tokensPath,
    required this.dataDirPath,
    required this.replyTo,
  });

  final RootIsolateToken rootIsolateToken;
  final String modelPath;
  final String tokensPath;
  final String dataDirPath;
  final SendPort replyTo;
}

class _GenerateRequest {
  const _GenerateRequest(this.text, this.speed, this.replyTo);
  final String text;
  final double speed;
  final SendPort replyTo;
}

class _GenerateReply {
  const _GenerateReply({this.samples, this.sampleRate, this.error});
  final Float32List? samples;
  final int? sampleRate;
  final String? error;
}

/// Runs sherpa-onnx's [sherpa_onnx.OfflineTts] entirely inside one dedicated
/// background isolate. Synthesis is real neural-net inference — not free —
/// and this app's whole premise is staying smooth, so it must never block
/// the UI isolate. The engine is created once and lives for the isolate's
/// lifetime; only generate requests cross the port after that (unlike
/// `Isolate.run`, which would respawn — and re-init the model — every call).
class SherpaTtsIsolate {
  SherpaTtsIsolate._(this._isolate, this._commands);

  final Isolate _isolate;
  final SendPort _commands;

  static Future<SherpaTtsIsolate> spawn({
    required String modelPath,
    required String tokensPath,
    required String dataDirPath,
  }) async {
    final bootPort = ReceivePort();
    final isolate = await Isolate.spawn(_entry, bootPort.sendPort);
    final commands = await bootPort.first as SendPort;
    bootPort.close();

    final readyPort = ReceivePort();
    commands.send(
      _InitRequest(
        rootIsolateToken: RootIsolateToken.instance!,
        modelPath: modelPath,
        tokensPath: tokensPath,
        dataDirPath: dataDirPath,
        replyTo: readyPort.sendPort,
      ),
    );
    final result = await readyPort.first;
    readyPort.close();
    if (result is String) {
      isolate.kill(priority: Isolate.immediate);
      throw StateError('sherpa-onnx init failed: $result');
    }

    return SherpaTtsIsolate._(isolate, commands);
  }

  Future<({Float32List samples, int sampleRate})> generate(
    String text, {
    double speed = 1.0,
  }) async {
    final replyPort = ReceivePort();
    _commands.send(_GenerateRequest(text, speed, replyPort.sendPort));
    final reply = await replyPort.first as _GenerateReply;
    replyPort.close();
    if (reply.error != null) throw StateError(reply.error!);
    return (samples: reply.samples!, sampleRate: reply.sampleRate!);
  }

  void dispose() {
    _isolate.kill(priority: Isolate.immediate);
  }

  static void _entry(SendPort bootSendPort) {
    final commands = ReceivePort();
    bootSendPort.send(commands.sendPort);

    sherpa_onnx.OfflineTts? tts;

    commands.listen((message) {
      if (message is _InitRequest) {
        _handleInit(message, (tts_) => tts = tts_);
      } else if (message is _GenerateRequest) {
        _handleGenerate(message, tts);
      }
    });
  }

  static void _handleInit(
    _InitRequest request,
    void Function(sherpa_onnx.OfflineTts) onReady,
  ) {
    try {
      BackgroundIsolateBinaryMessenger.ensureInitialized(
        request.rootIsolateToken,
      );
      sherpa_onnx.initBindings();

      final vits = sherpa_onnx.OfflineTtsVitsModelConfig(
        model: request.modelPath,
        tokens: request.tokensPath,
        dataDir: request.dataDirPath,
        lexicon: '',
      );
      final modelConfig = sherpa_onnx.OfflineTtsModelConfig(
        vits: vits,
        numThreads: 2,
        debug: false,
        provider: 'cpu',
      );
      final config = sherpa_onnx.OfflineTtsConfig(
        model: modelConfig,
        maxNumSenetences: 1,
      );

      onReady(sherpa_onnx.OfflineTts(config));
      request.replyTo.send(true);
    } catch (e) {
      request.replyTo.send(e.toString());
    }
  }

  static void _handleGenerate(
    _GenerateRequest request,
    sherpa_onnx.OfflineTts? tts,
  ) {
    if (tts == null) {
      request.replyTo.send(
        const _GenerateReply(error: 'TTS engine not initialized'),
      );
      return;
    }
    try {
      final audio = tts.generateWithConfig(
        text: request.text,
        config: sherpa_onnx.OfflineTtsGenerationConfig(
          sid: 0,
          speed: request.speed,
          silenceScale: 0.2,
        ),
      );
      request.replyTo.send(
        _GenerateReply(samples: audio.samples, sampleRate: audio.sampleRate),
      );
    } catch (e) {
      request.replyTo.send(_GenerateReply(error: e.toString()));
    }
  }
}
