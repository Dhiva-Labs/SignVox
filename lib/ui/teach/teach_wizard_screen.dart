import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion_energy.dart';
import '../../core/normalize.dart';
import '../../core/providers.dart';
import '../../core/resample.dart';
import '../../engines/dtw_engine.dart';
import '../../theme.dart';
import '../translate/hand_overlay_painter.dart';
import '../widgets/capture.dart';
import '../widgets/grouped.dart';
import '../widgets/nav.dart';

enum _WizardPhase { labelEntry, countdown, recording, review, saving }

/// Teach wizard (PLAN.md §4 screen 2 / §9): label a new sign, hold it
/// through a countdown, record up to 5 motion-segmented samples, then save
/// with a threshold computed from how consistent those samples were.
class TeachWizardScreen extends ConsumerStatefulWidget {
  const TeachWizardScreen({super.key});

  @override
  ConsumerState<TeachWizardScreen> createState() => _TeachWizardScreenState();
}

class _TeachWizardScreenState extends ConsumerState<TeachWizardScreen> {
  static const _targetSamples = 5;
  static const _minSamples = 3;
  static const _recordTimeout = Duration(seconds: 45);

  final _labelController = TextEditingController();
  final _spokenController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  _WizardPhase _phase = _WizardPhase.labelEntry;
  int _countdownValue = 3;
  final List<List<Float32List>> _capturedExemplars = [];
  MotionEnergySegmenter? _segmenter;
  VoidCallback? _frameListener;
  Timer? _timer;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    if (_frameListener != null) {
      ref.read(visionControllerProvider).frame.removeListener(_frameListener!);
    }
    _labelController.dispose();
    _spokenController.dispose();
    super.dispose();
  }

  void _startRecording() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _capturedExemplars.clear();
    _segmenter = MotionEnergySegmenter();
    setState(() {
      _phase = _WizardPhase.countdown;
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
    setState(() => _phase = _WizardPhase.recording);
    final controller = ref.read(visionControllerProvider);
    _frameListener = () {
      final frame = controller.frame.value;
      if (frame == null) return;
      final vector = buildTwoHandVector(frame.hands, dominantIsLeft: false);
      final segment = _segmenter!.addFrame(vector);
      if (segment == null) return;
      setState(() => _capturedExemplars.add(resampleSequence(segment, 32)));
      if (_capturedExemplars.length >= _targetSamples) _finishCapture();
    };
    controller.frame.addListener(_frameListener!);
    _timer?.cancel();
    _timer = Timer(_recordTimeout, _finishCapture);
  }

  void _finishCapture() {
    _timer?.cancel();
    final controller = ref.read(visionControllerProvider);
    if (_frameListener != null) {
      controller.frame.removeListener(_frameListener!);
      _frameListener = null;
    }
    if (_disposed) return;
    setState(() => _phase = _WizardPhase.review);
  }

  Future<void> _save() async {
    setState(() => _phase = _WizardPhase.saving);
    final repo = ref.read(signRepositoryProvider);
    const engine = DtwEngine();
    // Threshold from the *augmented* set, matching what SignsController will
    // actually classify against (PLAN_V2_RECOGNITION.md R4). Estimating it from
    // the 5 raw takes alone produced a threshold for a comparison the app never
    // makes, and 5 samples is far too few for a stable mean+2sigma anyway.
    final threshold = engine.computeThreshold(
      augmentExemplars(_capturedExemplars),
    );

    final label = _labelController.text.trim();
    final spoken = _spokenController.text.trim();
    final id = await repo.createSign(
      label: label,
      spokenText: spoken.isEmpty ? label : spoken,
      threshold: threshold,
    );
    for (final exemplar in _capturedExemplars) {
      await repo.addExemplar(id, exemplar);
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SvNavBar(title: 'New Sign'),
      body: switch (_phase) {
        _WizardPhase.labelEntry => _buildLabelEntry(),
        _WizardPhase.countdown || _WizardPhase.recording => _buildRecording(),
        _WizardPhase.review => _buildReview(),
        _WizardPhase.saving => const Center(
          child: CupertinoActivityIndicator(radius: 13),
        ),
      },
    );
  }

  Widget _buildLabelEntry() {
    final colors = context.colors;
    return Form(
      key: _formKey,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          GroupedSection(
            header: 'Name',
            footer:
                'You\'ll hold this sign through a 3-second countdown, then perform it '
                '$_targetSamples times (at least $_minSamples needed) with a brief pause between each.',
            children: [
              _FieldCell(
                controller: _labelController,
                placeholder: 'Sign name — e.g. coffee',
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter a name for this sign'
                    : null,
              ),
              _FieldCell(
                controller: _spokenController,
                placeholder: 'Spoken as (optional)',
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
            child: FilledButton(
              onPressed: _startRecording,
              child: const Text('Start Recording'),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Uses the front camera · nothing is saved as video',
              style: TextStyle(fontSize: 12, color: colors.tertiaryLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecording() {
    final controller = ref.read(visionControllerProvider);
    final theme = Theme.of(context).textTheme;
    final colors = context.colors;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(color: Color(0xFF101014)),
                      CustomPaint(
                        painter: HandOverlayPainter(controller.frame),
                      ),
                      if (_phase == _WizardPhase.countdown)
                        CountdownOverlay(_countdownValue),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          child: Column(
            children: [
              Text(
                _phase == _WizardPhase.countdown
                    ? 'Get ready…'
                    : 'Perform “${_labelController.text.trim()}” now',
                style: theme.titleMedium,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (var i = 0; i < _targetSamples; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 5,
                        decoration: BoxDecoration(
                          color: i < _capturedExemplars.length
                              ? colors.accent
                              : colors.fill,
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${_capturedExemplars.length} of $_targetSamples samples',
                style: TextStyle(fontSize: 13, color: colors.secondaryLabel),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReview() {
    final count = _capturedExemplars.length;
    final enoughSamples = count >= _minSamples;
    final colors = context.colors;
    final theme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              enoughSamples
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.exclamationmark_triangle_fill,
              size: 56,
              color: enoughSamples ? colors.success : colors.warning,
            ),
            const SizedBox(height: 16),
            Text(
              enoughSamples
                  ? 'Captured $count Sample${count == 1 ? '' : 's'}'
                  : 'Not Enough Samples',
              style: theme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                enoughSamples
                    ? '“${_labelController.text.trim()}” is ready to save.'
                    : 'Only captured $count of $_minSamples needed. Keep your hand clearly '
                          'visible and pause briefly between repeats.',
                style: theme.bodyMedium?.copyWith(color: colors.secondaryLabel),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 28),
            if (enoughSamples) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Save Sign'),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _startRecording,
                child: Text(enoughSamples ? 'Record Again' : 'Try Again'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A text field styled as one grouped-list cell.
class _FieldCell extends StatelessWidget {
  const _FieldCell({
    required this.controller,
    required this.placeholder,
    this.validator,
  });

  final TextEditingController controller;
  final String placeholder;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: TextFormField(
        controller: controller,
        validator: validator,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: placeholder,
          border: InputBorder.none,
          filled: false,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 7),
        ),
      ),
    );
  }
}
