import 'letter_engine.dart';

/// Result of feeding one frame to [SpellDecoder]: at most one letter commit
/// and/or one word commit can happen on the same frame (a word always
/// commits due to a pause, which by definition can't coincide with a fresh
/// letter commit on that same frame, but both fields exist so callers don't
/// need to special-case ordering).
class SpellDecoderResult {
  const SpellDecoderResult({this.committedLetter, this.committedWord});

  final String? committedLetter;
  final String? committedWord;

  bool get isEmpty => committedLetter == null && committedWord == null;
}

/// Spell-mode decoder (PLAN.md §5.5): turns a per-frame letter prediction
/// stream into committed letters and, after a pause, a committed word.
///
/// ## What changed in v1.1 (PLAN_V2_RECOGNITION.md R3)
///
/// v1.0 counted *frames*: N consecutive frames of the same argmax label above a
/// confidence threshold. Three things made that feel broken in real use, and
/// all three are fixed here.
///
/// 1. **Frame counting is device-dependent.** Effective FPS ranges 7–30 across
///    devices and thermal states (the emulator HUD measured 7–16), so "8
///    frames" meant anywhere from 260 ms to 1.1 s of holding. The hold is now a
///    *duration* accumulated from frame timestamps, so commit latency feels the
///    same everywhere. [holdFrames] still exists and maps to `frames * 33 ms`,
///    which both preserves the stored user preference and keeps the frame-rate
///    assumption in exactly one place.
/// 2. **One flickered frame reset everything.** A single noisy frame — motion
///    blur, a finger briefly occluding another — threw away the whole hold.
///    Now up to [flickerGrace] consecutive frames of a *different letter*
///    neither advance nor reset the hold; only a genuinely sustained different
///    letter takes over, and when it does it takes over retroactively from its
///    own first frame, so switching letters costs nothing.
/// 3. **Nothing knew the hand was moving.** Mid-transition poses were
///    classified as confident garbage letters and committed. [isTransitioning]
///    freezes the accumulator while the hand is in motion.
///
/// A `none` prediction still resets immediately rather than getting flicker
/// grace: post-R2 the model is explicitly trained on transition poses, so
/// `none` is a real verdict ("this is not a letter") and honouring it at once
/// is what stops phantom letters. Flicker grace covers letter-vs-letter
/// confusion only.
///
/// A letter commits once the same label has been held for [holdDuration] with
/// smoothed confidence above [commitConfidence] *and* a top1-minus-top2 margin
/// of at least [commitMargin], followed by a [cooldown]. Repeating the same
/// letter twice in a row (a double letter, e.g. the "LL" in "HELLO")
/// additionally requires confidence to have dipped below [recommitConfidence]
/// at some point since the last commit — otherwise simply continuing to hold
/// the same handshape would spam-commit it every time the cooldown elapses.
class SpellDecoder {
  SpellDecoder({
    int? holdFrames,
    Duration? holdDuration,
    this.commitConfidence = 0.8,
    this.commitMargin = 0.15,
    this.recommitConfidence = 0.5,
    this.flickerGrace = 2,
    this.cooldown = const Duration(milliseconds: 300),
    this.wordCommitPause = const Duration(seconds: 1),
    this.maxFrameGap = const Duration(milliseconds: 200),
  }) : holdDuration =
           holdDuration ??
           (holdFrames != null
               ? Duration(milliseconds: holdFrames * msPerFrameEstimate)
               : const Duration(milliseconds: 350));

  /// The frames->milliseconds conversion used for the legacy [holdFrames]
  /// preference. ~30 FPS was v1.0's implicit assumption; keeping it here means
  /// an existing user's stored slider position produces the same feel it did
  /// before the change, instead of silently doubling their hold time.
  static const int msPerFrameEstimate = 33;

  /// Mutable (not final): PLAN.md §4 screen 7 lets the user adjust this
  /// live from Settings without losing in-progress recognition state.
  Duration holdDuration;

  /// Legacy frame-count view of [holdDuration], for settings written before
  /// v1.1 and for tests that reason in frames.
  int get holdFrames =>
      (holdDuration.inMilliseconds / msPerFrameEstimate).round();

  set holdFrames(int frames) =>
      holdDuration = Duration(milliseconds: frames * msPerFrameEstimate);

  final double commitConfidence;

  /// Minimum top1 - top2 gap. Only meaningful because R2's temperature
  /// calibration made the probabilities honest; before that, both numbers were
  /// arbitrary.
  final double commitMargin;

  final double recommitConfidence;

  /// How many consecutive frames of a different letter are tolerated before the
  /// hold actually switches. 2 at ~15 FPS is ~130 ms — shorter than any real
  /// handshape change, longer than any single-frame glitch.
  final int flickerGrace;

  final Duration cooldown;
  final Duration wordCommitPause;

  /// Frame gaps longer than this contribute only this much to the hold. Without
  /// the clamp, the app being backgrounded for 10 s would instantly satisfy any
  /// hold on the next frame.
  final Duration maxFrameGap;

  String? _stableLabel;
  int _heldMs = 0;
  String? _pendingLabel;
  int _pendingMs = 0;
  int _pendingFrames = 0;
  DateTime? _lastFrameAt;
  DateTime? _cooldownUntil;
  String? _lastCommittedLabel;
  bool _dippedSinceLastCommit = true;
  DateTime? _pauseSince;
  final StringBuffer _currentWord = StringBuffer();

  String get currentWord => _currentWord.toString();

  /// The letter currently building toward a commit, if any.
  String? get candidateLabel => _stableLabel;

  /// 0->1 progress of the current hold, for the Translate screen's progress
  /// ring. Seeing the commit build is half of what makes recognition *feel*
  /// reliable, independent of whether it got the letter right.
  double get holdProgress {
    final target = holdDuration.inMilliseconds;
    if (target <= 0 || _stableLabel == null) return 0.0;
    final p = _heldMs / target;
    return p < 0 ? 0.0 : (p > 1 ? 1.0 : p);
  }

  /// Feed one frame's top prediction (null = no hand tracked this frame) and
  /// the current time. Call this on every frame, including no-hand frames — the
  /// EventChannel contract (PLAN.md §3) guarantees those still arrive, which is
  /// what lets the word-pause timeout be detected here without a separate
  /// polling timer.
  ///
  /// [isTransitioning] comes from `HandVelocityGate`: while true the hold is
  /// frozen (neither advanced nor reset), because a pose the hand is sweeping
  /// through is not a pose the user is holding.
  SpellDecoderResult addPrediction(
    LetterPrediction? prediction,
    DateTime now, {
    bool isTransitioning = false,
  }) {
    final dtMs = _tick(now);

    if (prediction == null || prediction.label == 'none') {
      _clearHold();
      _dippedSinceLastCommit = true; // hand leaving/relaxing counts as a dip
      _pauseSince ??= now;
      return SpellDecoderResult(committedWord: _checkWordTimeout(now));
    }
    _pauseSince = null;

    if (prediction.confidence < recommitConfidence) {
      _dippedSinceLastCommit = true;
    }

    if (_cooldownUntil != null && now.isBefore(_cooldownUntil!)) {
      return const SpellDecoderResult();
    }

    if (isTransitioning) {
      // Freeze: don't advance the hold, don't throw it away either. The user is
      // mid-gesture, and both committing and restarting would be wrong.
      return const SpellDecoderResult();
    }

    if (prediction.label != _stableLabel) {
      if (_stableLabel == null) {
        _stableLabel = prediction.label;
        _heldMs = dtMs;
        _clearPending();
      } else if (prediction.label == _pendingLabel) {
        _pendingMs += dtMs;
        _pendingFrames++;
        if (_pendingFrames > flickerGrace) {
          // Sustained switch: adopt it *retroactively* from the challenger's
          // own first frame, so changing letters is no slower than holding one.
          _stableLabel = _pendingLabel;
          _heldMs = _pendingMs;
          _clearPending();
        } else {
          return const SpellDecoderResult();
        }
      } else {
        _pendingLabel = prediction.label;
        _pendingMs = dtMs;
        _pendingFrames = 1;
        return const SpellDecoderResult();
      }
    } else {
      _heldMs += dtMs;
      _clearPending();
    }

    final sameAsLastCommit = prediction.label == _lastCommittedLabel;
    final allowedToCommit = !sameAsLastCommit || _dippedSinceLastCommit;

    if (_heldMs >= holdDuration.inMilliseconds &&
        prediction.confidence > commitConfidence &&
        prediction.margin >= commitMargin &&
        allowedToCommit) {
      _currentWord.write(prediction.label);
      _lastCommittedLabel = prediction.label;
      _dippedSinceLastCommit = false;
      _cooldownUntil = now.add(cooldown);
      _heldMs = 0;
      _clearPending();
      return SpellDecoderResult(committedLetter: prediction.label);
    }
    return const SpellDecoderResult();
  }

  int _tick(DateTime now) {
    final last = _lastFrameAt;
    _lastFrameAt = now;
    if (last == null) return msPerFrameEstimate;
    final dt = now.difference(last).inMilliseconds;
    if (dt <= 0) return 0;
    final cap = maxFrameGap.inMilliseconds;
    return dt > cap ? cap : dt;
  }

  void _clearHold() {
    _stableLabel = null;
    _heldMs = 0;
    _clearPending();
  }

  void _clearPending() {
    _pendingLabel = null;
    _pendingMs = 0;
    _pendingFrames = 0;
  }

  String? _checkWordTimeout(DateTime now) {
    if (_pauseSince == null) return null;
    if (now.difference(_pauseSince!) < wordCommitPause) return null;
    if (_currentWord.isEmpty) return null;
    final word = _currentWord.toString();
    _currentWord.clear();
    return word;
  }

  /// Removes the last committed letter from the in-progress word, if any.
  void removeLastLetter() {
    if (_currentWord.isEmpty) return;
    final trimmed = _currentWord.toString();
    _currentWord.clear();
    if (trimmed.length > 1) {
      _currentWord.write(trimmed.substring(0, trimmed.length - 1));
    }
  }

  void reset() {
    _clearHold();
    _lastFrameAt = null;
    _cooldownUntil = null;
    _lastCommittedLabel = null;
    _dippedSinceLastCommit = true;
    _pauseSince = null;
    _currentWord.clear();
  }
}
