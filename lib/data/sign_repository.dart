import 'dart:typed_data';

import 'package:drift/drift.dart';

import '../core/landmark_sequence_codec.dart';
import 'db.dart';

/// A taught sign plus its exemplar count, for the Vocabulary/Teach screens.
class SignSummary {
  const SignSummary({required this.sign, required this.exemplarCount});
  final Sign sign;
  final int exemplarCount;
}

/// CRUD for taught signs and their exemplars (PLAN.md §7 `signs`/`exemplars`
/// tables). Each exemplar is a resampled 32-frame x 129-dim sequence
/// (§6.3) — the public API here always deals in that structured
/// `List<Float32List>` shape (frame-by-frame, what DtwEngine/resample
/// consume); flattening to a single blob for storage is an implementation
/// detail contained entirely within this class.
///
/// History and phrases are P6's concern — that repository layer comes with
/// the Conversation-mode phase, not here.
class SignRepository {
  SignRepository(this._db);

  final AppDatabase _db;

  Future<List<SignSummary>> allSigns() async {
    final query = _db.select(_db.signs).join([
      leftOuterJoin(
        _db.exemplars,
        _db.exemplars.signId.equalsExp(_db.signs.id),
      ),
    ]);
    final rows = await query.get();

    final counts = <int, int>{};
    final signs = <int, Sign>{};
    for (final row in rows) {
      final sign = row.readTable(_db.signs);
      signs[sign.id] = sign;
      if (row.readTableOrNull(_db.exemplars) != null) {
        counts[sign.id] = (counts[sign.id] ?? 0) + 1;
      } else {
        counts.putIfAbsent(sign.id, () => 0);
      }
    }
    return [
      for (final sign in signs.values)
        SignSummary(sign: sign, exemplarCount: counts[sign.id] ?? 0),
    ]..sort((a, b) => a.sign.label.compareTo(b.sign.label));
  }

  Future<int> createSign({
    required String label,
    required String spokenText,
    required double threshold,
  }) {
    return _db
        .into(_db.signs)
        .insert(
          SignsCompanion.insert(
            label: label,
            spokenText: spokenText,
            threshold: threshold,
          ),
        );
  }

  /// [sequence] is one resampled exemplar: 32 frames, each a 129-float
  /// vector (§6.3) — flattened to a single blob for storage.
  Future<void> addExemplar(int signId, List<Float32List> sequence) async {
    await _db
        .into(_db.exemplars)
        .insert(
          ExemplarsCompanion.insert(
            signId: signId,
            landmarkSequence: _encode(flattenSequence(sequence)),
          ),
        );
    final count = await (_db.select(
      _db.exemplars,
    )..where((e) => e.signId.equals(signId))).get();
    await (_db.update(_db.signs)..where((s) => s.id.equals(signId))).write(
      SignsCompanion(sampleCount: Value(count.length)),
    );
  }

  /// Returns every exemplar for [signId], each reshaped back to its
  /// original 32-frame x 129-dim structure.
  Future<List<List<Float32List>>> exemplarsFor(int signId) async {
    final rows = await (_db.select(
      _db.exemplars,
    )..where((e) => e.signId.equals(signId))).get();
    return [
      for (final row in rows)
        unflattenSequence(_decode(row.landmarkSequence), frameDim: 129),
    ];
  }

  /// All enabled signs' exemplars in one query, for the Signs-mode DTW
  /// engine's 1-NN search (PLAN.md §6.3) — avoids one query per sign.
  Future<Map<Sign, List<List<Float32List>>>> enabledSignsWithExemplars() async {
    final signs = await (_db.select(
      _db.signs,
    )..where((s) => s.enabled.equals(true))).get();
    final result = <Sign, List<List<Float32List>>>{};
    for (final sign in signs) {
      result[sign] = await exemplarsFor(sign.id);
    }
    return result;
  }

  Future<void> setEnabled(int signId, bool enabled) {
    return (_db.update(_db.signs)..where((s) => s.id.equals(signId))).write(
      SignsCompanion(enabled: Value(enabled)),
    );
  }

  Future<void> updateSpokenText(int signId, String spokenText) {
    return (_db.update(_db.signs)..where((s) => s.id.equals(signId))).write(
      SignsCompanion(spokenText: Value(spokenText)),
    );
  }

  Future<void> updateThreshold(int signId, double threshold) {
    return (_db.update(_db.signs)..where((s) => s.id.equals(signId))).write(
      SignsCompanion(threshold: Value(threshold)),
    );
  }

  Future<void> deleteSign(int signId) {
    return (_db.delete(_db.signs)..where((s) => s.id.equals(signId))).go();
  }

  Uint8List _encode(Float32List floats) =>
      floats.buffer.asUint8List(floats.offsetInBytes, floats.lengthInBytes);

  Float32List _decode(Uint8List bytes) =>
      bytes.buffer.asFloat32List(bytes.offsetInBytes, bytes.lengthInBytes ~/ 4);
}
