import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// On-device personalisation for the letter model
/// (PLAN_V2_RECOGNITION.md R6).
///
/// One global model cannot fit every hand shape, skin tone, camera and signing
/// habit — and the honest limit of the bundled model is that it learned from a
/// handful of public-dataset signers. The fix that scales to mass users
/// *without any server* (so the zero-network guarantee is untouched) is to let
/// each user teach the app their own hand: capture a few frames per letter,
/// store the mean penultimate-layer embedding as that letter's prototype, and
/// blend a nearest-prototype score into the model's own probabilities.
///
/// Nothing here leaves the device: prototypes are a JSON file in the app's
/// documents directory, and the "reset" action deletes it.
///
/// The blend is deliberately capped: `beta = min(0.5, n / 30)` per letter, so
/// ten samples of a letter nudge the decision and thirty samples get an equal
/// vote, but the user can never fully override the trained model with a handful
/// of possibly-sloppy captures. Letters with no prototype fall through to pure
/// MLP behaviour.
class UserPrototypes {
  UserPrototypes({this.enabled = true, this.embeddingTemperature = 0.5});

  /// User-facing on/off switch (Settings). When false [isActive] is false and
  /// [blend] is never consulted, so personalisation costs literally nothing.
  bool enabled;

  /// Softmax temperature over negative squared distance. Larger = flatter, so
  /// a marginally-closer prototype doesn't dominate.
  final double embeddingTemperature;

  /// Logit of the implicit "matches none of the prototypes" outcome. -1.0 puts
  /// the crossover at a distance of `sqrt(embeddingTemperature) * |e|` from a
  /// prototype: closer than that and the prototype carries most of the mass,
  /// further and the background does.
  static const double _backgroundLogit = -1.0;

  final Map<String, Float32List> _means = {};
  final Map<String, int> _counts = {};

  /// Running sums, kept so a new sample can update a mean without re-reading
  /// every past capture.
  final Map<String, Float64List> _sums = {};

  bool get isActive => enabled && _means.isNotEmpty;

  int get letterCount => _means.length;

  Map<String, int> get sampleCounts => Map.unmodifiable(_counts);

  int sampleCountFor(String label) => _counts[label] ?? 0;

  /// Weight this letter's prototype currently carries, 0 when uncalibrated.
  double betaFor(String label) {
    final n = _counts[label] ?? 0;
    if (n == 0) return 0.0;
    return math.min(0.5, n / 30.0);
  }

  /// Adds one captured embedding for [label] and updates its prototype.
  void addSample(String label, Float32List embedding) {
    final sums = _sums.putIfAbsent(label, () => Float64List(embedding.length));
    if (sums.length != embedding.length) {
      // Model changed shape under us (new weights file with a different hidden
      // size). Old prototypes are meaningless against the new embedding space.
      clear();
      _sums[label] = Float64List(embedding.length);
    }
    final s = _sums[label]!;
    for (var i = 0; i < embedding.length; i++) {
      s[i] += embedding[i];
    }
    final n = (_counts[label] ?? 0) + 1;
    _counts[label] = n;
    final mean = _means.putIfAbsent(label, () => Float32List(embedding.length));
    for (var i = 0; i < mean.length; i++) {
      mean[i] = s[i] / n;
    }
  }

  /// Blends prototype similarity into [probs] for the labels that have one.
  ///
  /// Returns [out] (or a fresh list if omitted); [probs] is left untouched so
  /// the caller's own buffer stays valid.
  Float32List blend(
    Float32List probs,
    Float32List embedding,
    List<String> labels, {
    Float32List? out,
  }) {
    final result = out ?? Float32List(probs.length);
    result.setAll(0, probs);
    if (!isActive) return result;

    // Distances are normalized by the embedding's own magnitude so the
    // temperature means the same thing whatever scale the penultimate layer
    // happens to activate at — a raw squared distance would be meaningless the
    // moment the model is retrained with a different hidden size.
    var normE2 = 0.0;
    for (var k = 0; k < embedding.length; k++) {
      normE2 += embedding[k] * embedding[k];
    }
    final scale = embeddingTemperature * (normE2 + 1e-6);

    var any = false;
    var maxScore = _backgroundLogit;
    final scores = Float64List(labels.length);
    for (var i = 0; i < labels.length; i++) {
      final mean = _means[labels[i]];
      if (mean == null || mean.length != embedding.length) {
        scores[i] = double.negativeInfinity;
        continue;
      }
      var d2 = 0.0;
      for (var k = 0; k < mean.length; k++) {
        final d = embedding[k] - mean[k];
        d2 += d * d;
      }
      scores[i] = -d2 / scale;
      if (scores[i] > maxScore) maxScore = scores[i];
      any = true;
    }
    if (!any) return result;

    // Softmax over the calibrated prototypes **plus a constant background
    // term**. Without it the softmax is over the calibrated labels alone, so
    // with a single calibrated letter that letter's prototype score is 1.0 for
    // *any* hand — it would start winning everywhere the moment the user taught
    // it once. The background term is the "none of these prototypes" mass, and
    // it makes the score a genuine similarity rather than a ranking.
    var sum = math.exp(_backgroundLogit - maxScore);
    for (var i = 0; i < labels.length; i++) {
      if (scores[i].isFinite) {
        scores[i] = math.exp(scores[i] - maxScore);
        sum += scores[i];
      } else {
        scores[i] = 0.0;
      }
    }
    if (sum <= 0) return result;

    for (var i = 0; i < labels.length; i++) {
      final beta = betaFor(labels[i]);
      if (beta <= 0) continue;
      result[i] = (1 - beta) * probs[i] + beta * (scores[i] / sum);
    }

    // Blending per-label breaks normalization; renormalize so downstream
    // confidence gates (and the calibration baked into the model) still read as
    // probabilities.
    var total = 0.0;
    for (var i = 0; i < result.length; i++) {
      total += result[i];
    }
    if (total > 0) {
      for (var i = 0; i < result.length; i++) {
        result[i] /= total;
      }
    }
    return result;
  }

  void clearLabel(String label) {
    _means.remove(label);
    _counts.remove(label);
    _sums.remove(label);
  }

  void clear() {
    _means.clear();
    _counts.clear();
    _sums.clear();
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'enabled': enabled,
    'letters': {
      for (final entry in _means.entries)
        entry.key: {
          'count': _counts[entry.key],
          'mean': entry.value
              .map((v) => double.parse(v.toStringAsFixed(5)))
              .toList(),
        },
    },
  };

  static UserPrototypes fromJson(Map<String, dynamic> json) {
    final p = UserPrototypes(enabled: json['enabled'] as bool? ?? true);
    final letters =
        (json['letters'] as Map?)?.cast<String, dynamic>() ?? const {};
    letters.forEach((label, value) {
      final map = (value as Map).cast<String, dynamic>();
      final mean = Float32List.fromList(
        (map['mean'] as List)
            .map((v) => (v as num).toDouble())
            .toList(growable: false),
      );
      final count = (map['count'] as num?)?.toInt() ?? 1;
      p._means[label] = mean;
      p._counts[label] = count;
      final sums = Float64List(mean.length);
      for (var i = 0; i < mean.length; i++) {
        sums[i] = mean[i] * count;
      }
      p._sums[label] = sums;
    });
    return p;
  }

  String encode() => jsonEncode(toJson());

  static UserPrototypes decode(String source) =>
      fromJson(jsonDecode(source) as Map<String, dynamic>);
}
