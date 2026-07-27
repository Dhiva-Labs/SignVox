import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// Pure-Dart forward pass for a small feed-forward MLP. Chosen over
/// tflite_flutter as the primary path (not just a fallback) — a
/// 135->256->128->27 network is a few tens of thousands of multiply-adds per
/// frame, well within what Dart handles directly, and P1 already spent real
/// time on native-dependency friction (ABI gaps, R8 breakage) that a model this
/// small doesn't need to risk again. Dropout layers are training-only
/// regularization and are simply absent from this inference-time graph.
///
/// v1.1 (PLAN_V2_RECOGNITION.md R5) makes this allocation-free per frame:
/// weights live in one contiguous stride-indexed [Float32List] per layer rather
/// than a `List<Float32List>` of rows, and every layer's output buffer is
/// allocated once at load. The model is a singleton and [predict] runs on every
/// camera frame, so the old version's two allocations per layer per frame were
/// pure garbage-collector pressure on the one code path that must never stutter.
class MlpModel {
  MlpModel._(this._nets, this.labels)
    : _avg = Float32List(_nets.first.last.output.length);

  /// One or more independently trained networks over the same label set.
  /// v1.2's weights file may carry an ensemble (`"models": [...]`): each
  /// member is separately seeded and separately calibrated at train time, and
  /// inference averages their softmax outputs — reliably better *and* steadier
  /// than any single member, for a few extra tens of microseconds.
  final List<List<_DenseLayer>> _nets;
  final List<String> labels;

  /// Reused accumulator for the ensemble average (single-net models return
  /// the net's own output buffer directly and never touch this).
  final Float32List _avg;

  factory MlpModel.fromJson(Map<String, dynamic> json) {
    List<_DenseLayer> parseNet(List layersJson) => layersJson
        .map((l) => _DenseLayer.fromJson(l as Map<String, dynamic>))
        .toList(growable: false);
    final modelsJson = json['models'] as List?;
    final nets = modelsJson == null
        ? [parseNet(json['layers'] as List)]
        : [
            for (final m in modelsJson)
              parseNet((m as Map<String, dynamic>)['layers'] as List),
          ];
    final labels = (json['labels'] as List).cast<String>();
    return MlpModel._(nets, labels);
  }

  factory MlpModel.fromJsonString(String source) =>
      MlpModel.fromJson(jsonDecode(source) as Map<String, dynamic>);

  int get memberCount => _nets.length;

  /// Returns per-label probabilities (mean softmax across members).
  ///
  /// The returned list is a reusable buffer — copy it if you need it to
  /// survive the next call.
  Float32List predict(Float32List input) {
    if (_nets.length == 1) {
      var current = input;
      for (final layer in _nets.first) {
        current = layer.forward(current);
      }
      return current;
    }
    final avg = _avg..fillRange(0, _avg.length, 0);
    for (final net in _nets) {
      var current = input;
      for (final layer in net) {
        current = layer.forward(current);
      }
      for (var i = 0; i < avg.length; i++) {
        avg[i] += current[i];
      }
    }
    final inv = 1 / _nets.length;
    for (var i = 0; i < avg.length; i++) {
      avg[i] *= inv;
    }
    return avg;
  }

  /// The activation of the last hidden layer from the most recent [predict]
  /// call — the embedding on-device personalisation prototypes are built from
  /// (PLAN_V2_RECOGNITION.md R6). Same buffer-reuse caveat as [predict].
  ///
  /// For an ensemble this is always member 0's hidden layer: prototypes need
  /// one stable embedding definition, not an average of unrelated spaces.
  ///
  /// For a single-layer model there is no hidden layer, so this is the input
  /// itself, which keeps the contract total instead of throwing.
  Float32List get penultimate {
    final net = _nets.first;
    return net.length >= 2 ? net[net.length - 2].output : net.first.output;
  }

  int get embeddingDim => penultimate.length;
}

class _DenseLayer {
  _DenseLayer(this.weights, this.biases, this.activation, this.inputDim)
    : output = Float32List(biases.length);

  /// Row-major [outputIndex * inputDim + inputIndex].
  final Float32List weights;
  final Float32List biases;
  final String activation;
  final int inputDim;

  /// Reused across calls — see the class doc on why this matters.
  final Float32List output;

  factory _DenseLayer.fromJson(Map<String, dynamic> json) {
    final rows = (json['weights'] as List).cast<List>();
    final outDim = rows.length;
    final inDim = outDim == 0 ? 0 : rows.first.length;
    final flat = Float32List(outDim * inDim);
    for (var o = 0; o < outDim; o++) {
      final row = rows[o];
      if (row.length != inDim) {
        throw ArgumentError(
          'Ragged weight matrix: row $o has ${row.length}, expected $inDim',
        );
      }
      final base = o * inDim;
      for (var i = 0; i < inDim; i++) {
        flat[base + i] = (row[i] as num).toDouble();
      }
    }
    final biases = Float32List.fromList(
      (json['biases'] as List)
          .map((v) => (v as num).toDouble())
          .toList(growable: false),
    );
    return _DenseLayer(flat, biases, json['activation'] as String, inDim);
  }

  Float32List forward(Float32List input) {
    if (input.length != inputDim) {
      throw ArgumentError('Expected $inputDim inputs, got ${input.length}');
    }
    final out = output;
    final w = weights;
    for (var o = 0; o < out.length; o++) {
      final base = o * inputDim;
      double sum = biases[o];
      for (var i = 0; i < inputDim; i++) {
        sum += w[base + i] * input[i];
      }
      out[o] = sum;
    }
    switch (activation) {
      case 'relu':
        for (var i = 0; i < out.length; i++) {
          if (out[i] < 0) out[i] = 0;
        }
      case 'softmax':
        _softmaxInPlace(out);
      case 'none':
        break;
      default:
        throw ArgumentError('Unknown activation: $activation');
    }
    return out;
  }

  void _softmaxInPlace(Float32List x) {
    var maxVal = x[0];
    for (final v in x) {
      if (v > maxVal) maxVal = v;
    }
    double sum = 0;
    for (var i = 0; i < x.length; i++) {
      final e = math.exp(x[i] - maxVal);
      x[i] = e;
      sum += e;
    }
    for (var i = 0; i < x.length; i++) {
      x[i] /= sum;
    }
  }
}
