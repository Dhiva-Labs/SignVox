import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/datalab_recorder.dart';
import '../../core/normalize.dart';
import '../../core/providers.dart';
import '../../core/vision_channel.dart';
import '../../theme.dart';
import '../widgets/capture.dart';
import '../widgets/empty_state.dart';
import '../widgets/nav.dart';

enum _RecordPhase { idle, countdown, recording, done }

/// Alphabet recorder for letter-model training data (PLAN.md §4 screen 5 /
/// §9): pick a letter, hold the pose through a countdown, capture normalized
/// samples while a hand is tracked, and append them to that letter's CSV.
class DataLabScreen extends ConsumerStatefulWidget {
  const DataLabScreen({super.key});

  @override
  ConsumerState<DataLabScreen> createState() => _DataLabScreenState();
}

class _DataLabScreenState extends ConsumerState<DataLabScreen> {
  static final _labels = [
    for (var i = 0; i < 26; i++) String.fromCharCode(65 + i),
    'none',
  ];
  static const _targetSamples = 150;
  static const _recordDuration = Duration(seconds: 6);

  final _recorder = DataLabRecorder();
  CameraInit? _cameraInit;
  String? _errorMessage;
  String _selectedLabel = 'A';
  int _existingCount = 0;
  _RecordPhase _phase = _RecordPhase.idle;
  int _countdownValue = 3;
  final List<Float32List> _captured = [];
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
            'Camera permission is required to record training data.',
      );
      return;
    }
    try {
      final controller = ref.read(visionControllerProvider);
      final init = await controller.ensureStarted();
      if (_disposed) return;
      setState(() => _cameraInit = init);
      await _refreshExistingCount();
    } catch (e) {
      if (_disposed) return;
      setState(() => _errorMessage = 'Camera failed to start:\n$e');
    }
  }

  Future<void> _refreshExistingCount() async {
    final count = await _recorder.countExisting(_selectedLabel);
    if (_disposed) return;
    setState(() => _existingCount = count);
  }

  void _selectLabel(String label) {
    if (_phase == _RecordPhase.countdown || _phase == _RecordPhase.recording) {
      return;
    }
    setState(() {
      _selectedLabel = label;
      _phase = _RecordPhase.idle;
    });
    _refreshExistingCount();
  }

  void _startRecording() {
    _captured.clear();
    setState(() {
      _phase = _RecordPhase.countdown;
      _countdownValue = 3;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_disposed) return;
      setState(() => _countdownValue--);
      if (_countdownValue <= 0) {
        t.cancel();
        _beginCapture();
      }
    });
  }

  void _beginCapture() {
    setState(() => _phase = _RecordPhase.recording);
    final controller = ref.read(visionControllerProvider);
    _frameListener = () {
      final frame = controller.frame.value;
      if (frame == null || frame.hands.isEmpty) return;
      if (_captured.length >= _targetSamples) return;
      _captured.add(normalizeHand(frame.hands.first));
      setState(() {});
    };
    controller.frame.addListener(_frameListener!);
    _timer = Timer(_recordDuration, _finishCapture);
  }

  Future<void> _finishCapture() async {
    _timer?.cancel();
    final controller = ref.read(visionControllerProvider);
    if (_frameListener != null) {
      controller.frame.removeListener(_frameListener!);
      _frameListener = null;
    }
    if (_captured.isNotEmpty) {
      await _recorder.appendSamples(_selectedLabel, _captured);
    }
    if (_disposed) return;
    setState(() => _phase = _RecordPhase.done);
    await _refreshExistingCount();
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
    return Scaffold(
      appBar: const SvNavBar(title: 'Data Lab'),
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
    if (init == null) {
      return const Center(child: CupertinoActivityIndicator(radius: 13));
    }
    final controller = ref.read(visionControllerProvider);
    final colors = context.colors;
    final theme = Theme.of(context).textTheme;
    final isRecording =
        _phase == _RecordPhase.countdown || _phase == _RecordPhase.recording;

    return Column(
      children: [
        LetterPickerRow(
          labels: _labels,
          selected: _selectedLabel,
          enabled: !isRecording,
          onSelected: _selectLabel,
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CaptureCameraBox(
                init: init,
                frame: controller.frame,
                countdown: _phase == _RecordPhase.countdown
                    ? _countdownValue
                    : null,
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
                  '$_selectedLabel — $_existingCount sample${_existingCount == 1 ? '' : 's'} recorded',
                  style: theme.titleSmall,
                ),
                const SizedBox(height: 10),
                AnimatedOpacity(
                  opacity: _phase == _RecordPhase.recording ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        value: _captured.length / _targetSamples,
                        minHeight: 5,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${_captured.length} / $_targetSamples this session',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.secondaryLabel,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.destructive,
                    ),
                    onPressed: isRecording ? null : _startRecording,
                    child: Text(isRecording ? 'Recording…' : 'Record'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
