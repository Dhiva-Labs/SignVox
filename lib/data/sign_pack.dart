import 'dart:convert';

import '../core/landmark_sequence_codec.dart';
import 'sign_repository.dart';

/// Sign pack JSON format (PLAN.md §7): `{version, appVersion, signs:[...]}`.
/// Exemplars are base64-encoded flat float32 bytes (32x129 reshaped back on
/// import) so packs stay plain JSON, shareable via `share_plus`/read back
/// via `file_picker`.
class SignPack {
  static const currentVersion = 1;

  static Future<Map<String, dynamic>> export(
    SignRepository repository,
    List<int> signIds,
  ) async {
    final allSigns = await repository.allSigns();
    final byId = {for (final s in allSigns) s.sign.id: s.sign};

    final signs = <Map<String, dynamic>>[];
    for (final id in signIds) {
      final sign = byId[id];
      if (sign == null) continue;
      final exemplars = await repository.exemplarsFor(id);
      signs.add({
        'label': sign.label,
        'spokenText': sign.spokenText,
        'threshold': sign.threshold,
        'exemplars': [
          for (final ex in exemplars)
            base64Encode(flattenSequence(ex).buffer.asUint8List()),
        ],
      });
    }

    return {'version': currentVersion, 'signs': signs};
  }

  /// Imports every sign in [json] as a brand-new sign (never overwrites an
  /// existing one by name — a name clash just means two signs share a
  /// label, which is harmless since matching happens by id). Refuses
  /// unrecognized future major versions rather than guessing at their shape.
  static Future<int> import(
    SignRepository repository,
    Map<String, dynamic> json,
  ) async {
    final version = json['version'] as int?;
    if (version == null || version > currentVersion) {
      throw FormatException(
        'Unsupported sign pack version: $version (this app supports up to $currentVersion)',
      );
    }

    final signs = (json['signs'] as List).cast<Map<String, dynamic>>();
    var imported = 0;
    for (final signJson in signs) {
      final id = await repository.createSign(
        label: signJson['label'] as String,
        spokenText: signJson['spokenText'] as String,
        threshold: (signJson['threshold'] as num).toDouble(),
      );
      final exemplars = (signJson['exemplars'] as List).cast<String>();
      for (final encoded in exemplars) {
        final flat = base64Decode(encoded).buffer.asFloat32List();
        await repository.addExemplar(
          id,
          unflattenSequence(flat, frameDim: 129),
        );
      }
      imported++;
    }
    return imported;
  }
}
