import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign_vox/data/db.dart';
import 'package:sign_vox/data/sign_pack.dart';
import 'package:sign_vox/data/sign_repository.dart';

List<Float32List> _sequence(double fill) {
  return [for (var i = 0; i < 32; i++) Float32List.fromList(List.filled(129, fill))];
}

void main() {
  late AppDatabase db;
  late SignRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SignRepository(db);
  });

  tearDown(() => db.close());

  test('exports and re-imports a sign with its exemplars intact', () async {
    final id = await repo.createSign(label: 'coffee', spokenText: 'coffee please', threshold: 0.42);
    await repo.addExemplar(id, _sequence(1.0));
    await repo.addExemplar(id, _sequence(2.0));

    final json = await SignPack.export(repo, [id]);
    expect(json['version'], 1);

    final imported = await SignPack.import(repo, json);
    expect(imported, 1);

    final all = await repo.allSigns();
    expect(all, hasLength(2), reason: 'import creates a new sign rather than overwriting the original');
    final importedSummary = all.firstWhere((s) => s.sign.id != id);
    expect(importedSummary.sign.label, 'coffee');
    expect(importedSummary.sign.spokenText, 'coffee please');
    expect(importedSummary.sign.threshold, 0.42);
    expect(importedSummary.exemplarCount, 2);

    final exemplars = await repo.exemplarsFor(importedSummary.sign.id);
    expect(exemplars[0][0][0], 1.0);
    expect(exemplars[1][0][0], 2.0);
  });

  test('refuses to import a pack from an unsupported future version', () async {
    expect(
      () => SignPack.import(repo, {'version': 999, 'signs': []}),
      throwsA(isA<FormatException>()),
    );
  });
}
