import 'dart:typed_data';

/// Exponential-moving-average smoother over a whole probability vector
/// (PLAN_V2_RECOGNITION.md R3 step 1).
///
/// v1.0 fed the decoder raw per-frame argmax. At 10–30 FPS a single noisy
/// frame — a blink of motion blur, a finger briefly occluding another — was
/// enough to flip the top-1 label and reset the entire hold counter, which is
/// what "the letters won't commit" actually felt like. Averaging the
/// *distribution* rather than the winner fixes that at the source: one bad
/// frame moves the smoothed vector by [alpha], not all the way.
///
/// Reset whenever the hand is lost. Carrying probabilities across a gap would
/// let a letter from before the gap commit after it, which is worse than
/// simply starting over.
///
/// Allocation-free per frame (R5): the EMA is applied in place into a buffer
/// owned by this object, and [smoothed] hands back that same buffer.
class ProbSmoother {
  ProbSmoother({this.alpha = 0.3});

  /// Weight of the newest frame. Lower = steadier but laggier. 0.3 settles a
  /// changed distribution in ~4 frames, which at 15 FPS is well inside the
  /// 350 ms hold window, so smoothing costs no perceptible commit latency.
  final double alpha;

  Float32List? _state;

  /// The current smoothed vector, or null before the first frame since a reset.
  Float32List? get smoothed => _state;

  bool get isEmpty => _state == null;

  /// Folds [probs] into the running average and returns the smoothed vector.
  /// The returned list is owned by this smoother — copy it if you need to keep
  /// it beyond the next call.
  Float32List add(Float32List probs) {
    var state = _state;
    if (state == null || state.length != probs.length) {
      state = Float32List(probs.length);
      state.setAll(0, probs);
      _state = state;
      return state;
    }
    final a = alpha;
    final b = 1.0 - a;
    for (var i = 0; i < state.length; i++) {
      state[i] = state[i] * b + probs[i] * a;
    }
    return state;
  }

  void reset() {
    _state = null;
  }
}

/// Per-frame hand-motion gate (PLAN_V2_RECOGNITION.md R3 step 5).
///
/// Mid-transition poses are the single biggest source of phantom letters: the
/// hand sweeping from one handshape to the next passes through shapes that look
/// like a confident third letter. R2 teaches the model to call those `none`;
/// this gate is the belt to that model's braces — while the hand is visibly
/// moving, the hold accumulator neither advances nor resets, so a letter can
/// only commit out of a genuinely *held* pose.
///
/// The noise floor adapts the same way [MotionEnergySegmenter]'s does, because
/// "still" means something different for a shaky hand at arm's length than for
/// one braced against a table, and a fixed threshold would either never fire or
/// never stop firing.
class HandVelocityGate {
  HandVelocityGate({
    this.calibrationWindow = 45,
    this.thresholdMultiplier = 2.5,
    this.initialNoiseFloor = 0.004,
  }) : _noiseFloor = initialNoiseFloor;

  final int calibrationWindow;
  final double thresholdMultiplier;
  final double initialNoiseFloor;

  double _noiseFloor;
  Float32List? _previous;
  double _velocity = 0.0;

  /// Mean |delta| per dimension between the last two frames.
  double get velocity => _velocity;

  double get threshold => _noiseFloor * thresholdMultiplier;

  /// Feed one normalized 63-vector; returns true when the hand is moving fast
  /// enough that this frame should not count toward a hold.
  bool addFrame(Float32List normalized63) {
    final previous = _previous;
    if (previous == null || previous.length != normalized63.length) {
      _previous = Float32List.fromList(normalized63);
      _velocity = 0.0;
      return false;
    }
    var sum = 0.0;
    for (var i = 0; i < normalized63.length; i++) {
      final d = normalized63[i] - previous[i];
      sum += d < 0 ? -d : d;
    }
    _velocity = sum / normalized63.length;
    previous.setAll(0, normalized63);

    final moving = _velocity > threshold;
    if (!moving) {
      // Only adapt while still, so a long sign doesn't drag the floor up until
      // nothing counts as motion any more.
      final a = 1.0 / calibrationWindow;
      _noiseFloor = _noiseFloor * (1 - a) + _velocity * a;
      if (_noiseFloor < 1e-5) _noiseFloor = 1e-5;
    }
    return moving;
  }

  void reset() {
    _previous = null;
    _velocity = 0.0;
    _noiseFloor = initialNoiseFloor;
  }
}
