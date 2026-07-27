import 'dart:typed_data';

/// Motion-energy segmenter for Signs mode (PLAN.md §5.4): finds where one
/// sign ends and the next begins by watching how fast the two-hand feature
/// vector is changing, against a noise floor that adapts to how "twitchy" a
/// relaxed hand naturally is versus one that's actively signing.
class MotionEnergySegmenter {
  MotionEnergySegmenter({
    this.startFrames = 3,
    this.endFrames = 8,
    this.minSegmentFrames = 8,
    this.maxSegmentFrames = 90,
    this.calibrationWindow = 60,
  });

  final int startFrames;
  final int endFrames;
  final int minSegmentFrames;
  final int maxSegmentFrames;

  /// Frames the idle-noise-floor EMA averages over (~2s at 30fps).
  final int calibrationWindow;

  Float32List? _previous;
  final List<Float32List> _pending = [];
  final List<Float32List> _segment = [];
  bool _inSegment = false;
  int _belowCount = 0;
  double _noiseFloor = 0.02;

  bool get isInSegment => _inSegment;

  /// Feed one normalized two-hand feature vector (129 floats). Returns the
  /// completed segment's frames when one just ended and passed the
  /// min/max-length filter, otherwise null.
  List<Float32List>? addFrame(Float32List frame) {
    final energy = _previous == null ? 0.0 : _meanAbsDiff(_previous!, frame);
    _previous = frame;

    final hiThreshold = _noiseFloor * 3;
    final loThreshold = _noiseFloor * 1.5;
    _updateNoiseFloor(energy);

    if (!_inSegment) {
      return _feedIdle(frame, energy, hiThreshold);
    }
    return _feedActive(frame, energy, loThreshold);
  }

  List<Float32List>? _feedIdle(
    Float32List frame,
    double energy,
    double hiThreshold,
  ) {
    if (energy <= hiThreshold) {
      _pending.clear();
      return null;
    }
    _pending.add(frame);
    if (_pending.length < startFrames) return null;

    _inSegment = true;
    _belowCount = 0;
    _segment
      ..clear()
      ..addAll(_pending);
    _pending.clear();
    return null;
  }

  List<Float32List>? _feedActive(
    Float32List frame,
    double energy,
    double loThreshold,
  ) {
    _segment.add(frame);
    if (energy >= loThreshold) {
      _belowCount = 0;
      return null;
    }
    _belowCount++;
    if (_belowCount < endFrames) return null;

    _inSegment = false;
    final segment = List<Float32List>.of(_segment);
    _segment.clear();
    final withinBounds =
        segment.length >= minSegmentFrames &&
        segment.length <= maxSegmentFrames;
    return withinBounds ? segment : null;
  }

  void _updateNoiseFloor(double energy) {
    if (_inSegment || _pending.isNotEmpty) return; // freeze during motion
    final alpha = 1 / calibrationWindow;
    _noiseFloor = _noiseFloor * (1 - alpha) + energy * alpha;
  }

  double _meanAbsDiff(Float32List a, Float32List b) {
    double sum = 0;
    for (var i = 0; i < a.length; i++) {
      sum += (a[i] - b[i]).abs();
    }
    return sum / a.length;
  }

  void reset() {
    _previous = null;
    _pending.clear();
    _segment.clear();
    _inSegment = false;
    _belowCount = 0;
  }
}
