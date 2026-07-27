import 'dart:typed_data';

/// Reshapes a 32-frame x N-dim exemplar sequence into one flat Float32List
/// and back — shared by [SignRepository]'s blob storage and [SignPack]'s
/// base64 JSON export, since both need the exact same byte layout.
Float32List flattenSequence(List<Float32List> frames) {
  final dim = frames.first.length;
  final out = Float32List(frames.length * dim);
  for (var i = 0; i < frames.length; i++) {
    out.setRange(i * dim, (i + 1) * dim, frames[i]);
  }
  return out;
}

List<Float32List> unflattenSequence(Float32List flat, {required int frameDim}) {
  final frameCount = flat.length ~/ frameDim;
  return [
    for (var i = 0; i < frameCount; i++)
      flat.sublist(i * frameDim, (i + 1) * frameDim),
  ];
}
