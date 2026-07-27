import 'dart:math' as math;
import 'dart:typed_data';

import 'letter_engine.dart';

/// Rule-based ASL digit recognizer (0–9) for Numbers mode.
///
/// Digits are deliberately NOT ten extra classes on the letter model, because
/// ASL itself overlaps them: 0 is the O handshape, 2 is V, 6 is W, 9 is F,
/// and 1/4 are near-twins of D/B. No classifier can separate identical
/// shapes — signers disambiguate by context, so the app does too, with an
/// explicit ABC/123 mode switch.
///
/// Inside Numbers mode, digit handshapes are geometrically crisp: a binary
/// pattern of which fingers are extended plus which fingertip the thumb
/// touches. That makes deterministic geometry — soft finger-extension and
/// thumb-contact scores over the normalized landmarks — more robust than a
/// learned model trained on no data, and it needs no dataset or license at
/// all. For the digits that share a letter's exact shape, the calibrated
/// letter ensemble's own probability is blended in (max), so 0/2/6/9 get the
/// full benefit of the trained model too.
///
/// All factors are pure distances — no left/right or up/down assumptions —
/// so both hands and any camera mirroring behave identically.
class DigitEngine {
  DigitEngine();

  static const labels = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'none'];

  static const _noneIndex = 10;

  final Float32List _scores = Float32List(labels.length);

  // MediaPipe landmark indices.
  static const _wrist = 0;
  static const _thumbTip = 4;
  static const _indexMcp = 5, _indexTip = 8;
  static const _middleMcp = 9, _middleTip = 12;
  static const _ringMcp = 13, _ringTip = 16;
  static const _pinkyMcp = 17, _pinkyTip = 20;

  /// Digit pseudo-probabilities for one normalized hand (63 floats, the same
  /// vector the letter engine consumes). Pass the letter ensemble's
  /// [letterProbs]/[letterLabels] to blend the letter-identical shapes.
  /// The returned buffer is owned by the engine and overwritten per call.
  Float32List probabilities(
    Float32List n, {
    Float32List? letterProbs,
    List<String>? letterLabels,
  }) {
    double d(int a, int b) {
      final dx = n[a * 3] - n[b * 3];
      final dy = n[a * 3 + 1] - n[b * 3 + 1];
      final dz = n[a * 3 + 2] - n[b * 3 + 2];
      return math.sqrt(dx * dx + dy * dy + dz * dz);
    }

    double sig(double v) => 1.0 / (1.0 + math.exp(-v));

    // Extension: how far past its own knuckle a fingertip reaches from the
    // wrist. ~1.8 fully extended, ~1.05 curled, in wrist->middle-MCP units.
    double ext(int mcp, int tip) {
      final base = d(_wrist, mcp);
      final reach = d(_wrist, tip) / (base < 1e-4 ? 1e-4 : base);
      return sig((reach - 1.35) * 8);
    }

    // Thumb-to-fingertip contact — the defining feature of 6/7/8/9/0.
    double touch(int tip) => sig((0.30 - d(_thumbTip, tip)) * 10);

    final extI = ext(_indexMcp, _indexTip);
    final extM = ext(_middleMcp, _middleTip);
    final extR = ext(_ringMcp, _ringTip);
    final extP = ext(_pinkyMcp, _pinkyTip);

    // Thumb held out to the side vs tucked against the palm (3/5 vs 1/2/4).
    final thumbOut = sig((d(_thumbTip, _indexMcp) - 0.55) * 10);
    final thumbTucked = 1.0 - thumbOut;

    // V-spread separates digit 2 from the U-like "fingers together" shape.
    final spreadIM = sig((d(_indexTip, _middleTip) - 0.30) * 8);

    final s = _scores;
    s[1] = extI * (1 - extM) * (1 - extR) * (1 - extP) * thumbTucked;
    s[2] = extI * extM * (1 - extR) * (1 - extP) * spreadIM * thumbTucked;
    s[3] = extI * extM * (1 - extR) * (1 - extP) * thumbOut;
    s[4] = extI * extM * extR * extP * thumbTucked;
    s[5] = extI * extM * extR * extP * thumbOut;
    s[6] = extI * extM * extR * touch(_pinkyTip);
    s[7] = extI * extM * extP * touch(_ringTip);
    s[8] = extI * extR * extP * touch(_middleTip);
    s[9] = extM * extR * extP * touch(_indexTip);
    // 0/O: every fingertip curls onto the thumb in a ring.
    s[0] =
        touch(_indexTip) * touch(_middleTip) * touch(_ringTip) * touch(_pinkyTip);

    // Letter-identical (or near-identical) shapes borrow the trained
    // ensemble's opinion — the stronger of geometry and learned model wins.
    if (letterProbs != null && letterLabels != null) {
      double p(String label) {
        final i = letterLabels.indexOf(label);
        return i < 0 ? 0.0 : letterProbs[i];
      }

      s[0] = math.max(s[0], p('O'));
      s[2] = math.max(s[2], p('V'));
      s[6] = math.max(s[6], p('W'));
      s[9] = math.max(s[9], p('F'));
      // Near-twins, not identical (thumb detail differs) — damped.
      s[1] = math.max(s[1], p('D') * 0.85);
      s[4] = math.max(s[4], p('B') * 0.85);
    }

    var top = 0.0;
    for (var i = 0; i < _noneIndex; i++) {
      if (s[i] > top) top = s[i];
    }
    s[_noneIndex] = math.max(0.04, (1.0 - top) * 0.6);

    // Sharpen and normalize so a clean pose clears the decoder's confidence
    // gate the way a calibrated softmax would.
    var sum = 0.0;
    for (var i = 0; i < s.length; i++) {
      s[i] = s[i] * s[i];
      sum += s[i];
    }
    final inv = 1.0 / (sum < 1e-9 ? 1e-9 : sum);
    for (var i = 0; i < s.length; i++) {
      s[i] *= inv;
    }
    return s;
  }

  /// Ranks a (possibly smoothed) digit probability vector — same contract as
  /// LetterEngine.topOf, so the decoder and candidate bar work unchanged.
  LetterPrediction topOf(Float32List probs) {
    var i1 = 0, i2 = -1, i3 = -1;
    for (var i = 1; i < probs.length; i++) {
      if (probs[i] > probs[i1]) {
        i3 = i2;
        i2 = i1;
        i1 = i;
      } else if (i2 < 0 || probs[i] > probs[i2]) {
        i3 = i2;
        i2 = i;
      } else if (i3 < 0 || probs[i] > probs[i3]) {
        i3 = i;
      }
    }
    return LetterPrediction(
      label: labels[i1],
      confidence: probs[i1],
      runnerUpLabel: i2 >= 0 ? labels[i2] : null,
      runnerUpConfidence: i2 >= 0 ? probs[i2] : 0.0,
      thirdLabel: i3 >= 0 ? labels[i3] : null,
      thirdConfidence: i3 >= 0 ? probs[i3] : 0.0,
    );
  }
}
