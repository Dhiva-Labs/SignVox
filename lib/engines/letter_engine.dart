import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import 'letter_features.dart';
import 'mlp_dart.dart';
import 'user_prototypes.dart';

/// One frame's letter verdict. Carries the runner-up and third place too, so
/// the decoder can apply a margin gate (PLAN_V2_RECOGNITION.md R3 step 4) and
/// the UI can show a top-3 candidate bar without re-running inference.
///
/// [runnerUpLabel] is nullable and [margin] answers 1.0 when it's absent, so a
/// caller that only knows the winner (tests, older call sites) is never
/// accidentally blocked by the margin gate.
class LetterPrediction {
  const LetterPrediction({
    required this.label,
    required this.confidence,
    this.runnerUpLabel,
    this.runnerUpConfidence = 0.0,
    this.thirdLabel,
    this.thirdConfidence = 0.0,
  });

  final String label;
  final double confidence;
  final String? runnerUpLabel;
  final double runnerUpConfidence;
  final String? thirdLabel;
  final double thirdConfidence;

  /// How far clear of second place the winner is. A high-confidence prediction
  /// that barely beats its runner-up is exactly the ambiguous case — M vs N, U
  /// vs R — where committing early produces a wrong letter the user then has to
  /// delete, so the decoder requires margin as well as confidence.
  double get margin =>
      runnerUpLabel == null ? 1.0 : confidence - runnerUpConfidence;
}

/// Wraps the letter MLP (PLAN.md §6.1): takes one hand's normalized 63 floats,
/// returns the top predicted label ("A".."Z" or "none") with its confidence.
/// Runs every frame in Spell mode.
///
/// v1.1 additions:
/// - **Versioned features.** The weights JSON may declare `"featureSet": "v2"`,
///   in which case the normalized 63 is expanded by [featuresV2] before the
///   forward pass. A file with no `featureSet` is a v1 raw-63 model and keeps
///   working unchanged — old Data Lab-trained weights don't become garbage the
///   day this ships.
/// - **On-device personalisation** (R6): an optional [UserPrototypes] blends
///   per-letter user embeddings into the model's own probabilities.
/// - **Allocation-free hot path** (R5): feature and probability buffers are
///   owned by the engine and reused every frame.
class LetterEngine {
  LetterEngine._(this._model, this.featureSet)
    : _featureBuffer = featureSet == 'v2' ? Float32List(featureDimV2) : null,
      _blended = Float32List(_model.labels.length);

  final MlpModel _model;

  /// `"v2"` or `"raw63"`. Exposed so the HUD/diagnostics can show which model
  /// generation is actually loaded.
  final String featureSet;

  final Float32List? _featureBuffer;
  final Float32List _blended;

  /// Set to enable on-device personalisation; null disables it entirely.
  UserPrototypes? prototypes;

  List<String> get labels => _model.labels;

  static Future<LetterEngine> load({
    String assetPath = 'assets/models/letters_weights.json',
  }) async {
    final source = await rootBundle.loadString(assetPath);
    return LetterEngine.fromJsonString(source);
  }

  static LetterEngine fromJsonString(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    final model = MlpModel.fromJson(json);
    // Absent == v1 (raw 63 inputs).
    final featureSet = (json['featureSet'] as String?) ?? 'raw63';
    return LetterEngine._(model, featureSet);
  }

  /// Probability vector for one hand. The returned list is owned by the engine
  /// and overwritten on the next call.
  Float32List probabilities(Float32List normalizedHand63) {
    final input = _featureBuffer == null
        ? normalizedHand63
        : featuresV2(normalizedHand63, out: _featureBuffer);
    final probs = _model.predict(input);

    final protos = prototypes;
    if (protos == null || !protos.isActive) return probs;
    return protos.blend(
      probs,
      _model.penultimate,
      _model.labels,
      out: _blended,
    );
  }

  /// Convenience wrapper: probabilities plus [topOf] in one call.
  LetterPrediction predict(Float32List normalizedHand63) =>
      topOf(probabilities(normalizedHand63));

  /// Ranks a (possibly smoothed) probability vector into a [LetterPrediction].
  /// Kept separate from [probabilities] so `ProbSmoother` can sit between them.
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
    final labels = _model.labels;
    return LetterPrediction(
      label: labels[i1],
      confidence: probs[i1],
      runnerUpLabel: i2 >= 0 ? labels[i2] : null,
      runnerUpConfidence: i2 >= 0 ? probs[i2] : 0.0,
      thirdLabel: i3 >= 0 ? labels[i3] : null,
      thirdConfidence: i3 >= 0 ? probs[i3] : 0.0,
    );
  }

  /// The penultimate-layer activation from the most recent [probabilities]
  /// call — the embedding personalisation prototypes are built from (R6).
  Float32List get embedding => _model.penultimate;
}
