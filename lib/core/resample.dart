import 'dart:typed_data';

/// Resamples a variable-length sequence of equal-dimension feature vectors
/// to exactly [targetLength] frames via linear interpolation (PLAN.md §5.5)
/// — segments captured at different speeds/durations become comparable,
/// fixed-length DTW exemplars/queries.
List<Float32List> resampleSequence(List<Float32List> frames, int targetLength) {
  if (frames.isEmpty) {
    throw ArgumentError('Cannot resample an empty sequence');
  }
  if (frames.length == 1) {
    return List.generate(
      targetLength,
      (_) => Float32List.fromList(frames.first),
    );
  }

  final dim = frames.first.length;
  final lastIndex = frames.length - 1;
  final out = List.generate(targetLength, (_) => Float32List(dim));

  for (var t = 0; t < targetLength; t++) {
    final pos = targetLength == 1 ? 0.0 : t * lastIndex / (targetLength - 1);
    final i0 = pos.floor().clamp(0, lastIndex);
    final i1 = (i0 + 1).clamp(0, lastIndex);
    final frac = pos - i0;
    final a = frames[i0];
    final b = frames[i1];
    final outFrame = out[t];
    for (var d = 0; d < dim; d++) {
      outFrame[d] = a[d] + (b[d] - a[d]) * frac;
    }
  }
  return out;
}
