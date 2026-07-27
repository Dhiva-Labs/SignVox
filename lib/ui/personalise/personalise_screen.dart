import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/normalize.dart';
import '../../core/prototype_store.dart';
import '../../core/providers.dart';
import '../../core/vision_channel.dart';
import '../../engines/letter_engine.dart';
import '../../engines/user_prototypes.dart';
import '../../theme.dart';
import '../widgets/capture.dart';
import '../widgets/empty_state.dart';
import '../widgets/nav.dart';
import '../widgets/sv_dialogs.dart';

enum _Phase { idle, countdown, capturing, done }

/// "Improve recognition" — guided per-letter capture that teaches this phone
/// the user's own hand (PLAN_V2_RECOGNITION.md R6).
///
/// The bundled model learned from a handful of public-dataset signers; no
/// single global model fits every hand shape, skin tone, camera and signing
/// habit. Rather than shipping a bigger model or (worse) collecting data to a
/// server, each user can spend ten seconds per weak letter and get a prototype
/// blended into that letter's score locally.
///
/// Deliberately capture-only: it stores the mean penultimate-layer *embedding*
/// per letter, not the frames. There is nothing here that could be exfiltrated
/// even if the app had a network permission, which it does not.
class PersonaliseScreen extends ConsumerStatefulWidget {
  const PersonaliseScreen({super.key});

  @override
  ConsumerState<PersonaliseScreen> createState() => _PersonaliseScreenState();
}

class _PersonaliseScreenState extends ConsumerState<PersonaliseScreen> {
  static final _labels = [
    for (var i = 0; i < 26; i++) String.fromCharCode(65 + i),
  ];
  static const _targetSamples = 10;
  static const _captureDuration = Duration(seconds: 4);

  /// Short, varied prompts — the same idea as the Data Lab's variation hints.
  /// Ten frames of one frozen pose teach the model one pose; ten frames across
  /// a little natural variation teach it the letter.
  static const _prompts = [
    'Hold the letter naturally',
    'Tilt your hand slightly',
    'Move a little closer',
  ];

  CameraInit? _cameraInit;
  String? _errorMessage;
  String _selected = 'A';
  _Phase _phase = _Phase.idle;
  int _countdown = 3;
  int _capturedThisRound = 0;
  UserPrototypes? _prototypes;
  LetterEngine? _engine;
  VoidCallback? _frameListener;
  Timer? _timer;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final status = await Permission.camera.request();
    if (_disposed) return;
    if (!status.isGranted) {
      setState(
        () => _errorMessage =
            'Camera permission is required to personalise recognition.',
      );
      return;
    }
    try {
      final engine = await LetterEngine.load();
      final prototypes = await loadUserPrototypes();
      final init = await ref.read(visionControllerProvider).ensureStarted();
      if (_disposed) return;
      setState(() {
        _engine = engine;
        _prototypes = prototypes;
        _cameraInit = init;
      });
    } catch (e) {
      if (_disposed) return;
      setState(() => _errorMessage = 'Camera failed to start:\n$e');
    }
  }

  void _start() {
    setState(() {
      _phase = _Phase.countdown;
      _countdown = 3;
      _capturedThisRound = 0;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_disposed) return;
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        _beginCapture();
      }
    });
  }

  void _beginCapture() {
    setState(() => _phase = _Phase.capturing);
    final controller = ref.read(visionControllerProvider);
    final engine = _engine!;
    final leftHanded = ref.read(appSettingsProvider).data.value.leftHandedMode;

    _frameListener = () {
      final frame = controller.frame.value;
      if (frame == null || frame.hands.isEmpty) return;
      if (_capturedThisRound >= _targetSamples) return;
      final hand = frame.hands.firstWhere(
        (h) => h.isLeft == leftHanded,
        orElse: () => frame.hands.first,
      );
      if (hand.score < 0.5) return;
      // Run inference purely for its embedding; the predicted label is
      // irrelevant here — the user is telling us the truth by picking a letter.
      engine.probabilities(normalizeHand(hand));
      // The engine hands back a buffer it overwrites next frame, so a stored
      // sample has to be a copy.
      _prototypes!.addSample(_selected, Float32List.fromList(engine.embedding));
      setState(() => _capturedThisRound++);
    };
    controller.frame.addListener(_frameListener!);
    _timer = Timer(_captureDuration, _finish);
  }

  Future<void> _finish() async {
    _timer?.cancel();
    final controller = ref.read(visionControllerProvider);
    if (_frameListener != null) {
      controller.frame.removeListener(_frameListener!);
      _frameListener = null;
    }
    if (_capturedThisRound > 0) await saveUserPrototypes(_prototypes!);
    if (_disposed) return;
    setState(() => _phase = _Phase.done);
  }

  Future<void> _resetAll() async {
    final confirmed = await showSvConfirm(
      context,
      title: 'Reset Personalisation?',
      message:
          'Everything this phone has learned about your hand will be '
          'deleted. The bundled model is unaffected.',
      confirmLabel: 'Reset',
      destructive: true,
    );
    if (!confirmed) return;
    _prototypes!.clear();
    await deleteUserPrototypes();
    if (_disposed) return;
    setState(() => _phase = _Phase.idle);
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    if (_frameListener != null) {
      ref.read(visionControllerProvider).frame.removeListener(_frameListener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: SvNavBar(
        title: 'Improve Recognition',
        actions: [
          if (_prototypes != null && _prototypes!.letterCount > 0)
            IconButton(
              tooltip: 'Reset personalisation',
              onPressed: _resetAll,
              icon: Icon(
                CupertinoIcons.arrow_counterclockwise,
                size: 22,
                color: colors.destructive,
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final error = _errorMessage;
    if (error != null) {
      return SvEmptyState(
        icon: CupertinoIcons.videocam,
        title: 'Camera Unavailable',
        message: error,
      );
    }
    final init = _cameraInit;
    final prototypes = _prototypes;
    if (init == null || prototypes == null) {
      return const Center(child: CupertinoActivityIndicator(radius: 13));
    }
    final controller = ref.read(visionControllerProvider);
    final colors = context.colors;
    final theme = Theme.of(context).textTheme;
    final busy = _phase == _Phase.countdown || _phase == _Phase.capturing;
    final count = prototypes.sampleCountFor(_selected);

    return Column(
      children: [
        LetterPickerRow(
          labels: _labels,
          selected: _selected,
          enabled: !busy,
          countFor: prototypes.sampleCountFor,
          onSelected: (label) => setState(() {
            _selected = label;
            _phase = _Phase.idle;
          }),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CaptureCameraBox(
                init: init,
                frame: controller.frame,
                countdown: _phase == _Phase.countdown ? _countdown : null,
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Column(
              children: [
                Text(
                  _phase == _Phase.capturing
                      ? _prompts[_capturedThisRound ~/ 4 % _prompts.length]
                      : count > 0
                      ? '$_selected — $count sample${count == 1 ? '' : 's'} learned '
                            '(weight ${(prototypes.betaFor(_selected) * 100).round()}%)'
                      : '$_selected — not personalised yet',
                  textAlign: TextAlign.center,
                  style: theme.titleSmall,
                ),
                const SizedBox(height: 10),
                AnimatedOpacity(
                  opacity: _phase == _Phase.capturing ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: LinearProgressIndicator(
                    value: _capturedThisRound / _targetSamples,
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: busy ? null : _start,
                    child: Text(busy ? 'Capturing…' : 'Teach $_selected'),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Stays on this phone. Nothing is uploaded — the app has no network permission.',
                  style: TextStyle(fontSize: 12, color: colors.tertiaryLabel),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
