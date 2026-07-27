import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign_vox/data/db.dart';
import 'package:sign_vox/data/sign_repository.dart';

/// A synthetic 32-frame x 129-dim exemplar sequence, every value set to
/// [fill] — stands in for a real DTW exemplar for repository-layer testing.
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

  test('creates a sign and lists it with a zero exemplar count', () async {
    await repo.createSign(label: 'hello', spokenText: 'hello', threshold: 0.5);

    final signs = await repo.allSigns();
    expect(signs, hasLength(1));
    expect(signs.single.sign.label, 'hello');
    expect(signs.single.sign.spokenText, 'hello');
    expect(signs.single.exemplarCount, 0);
    expect(signs.single.sign.enabled, isTrue, reason: 'signs should default to enabled');
  });

  test('adding exemplars increments both the count and stored sampleCount', () async {
    final id = await repo.createSign(label: 'thanks', spokenText: 'thank you', threshold: 0.5);

    await repo.addExemplar(id, _sequence(1.0));
    await repo.addExemplar(id, _sequence(2.0));

    final signs = await repo.allSigns();
    expect(signs.single.exemplarCount, 2);
    expect(signs.single.sign.sampleCount, 2);
  });

  test('round-trips a 32x129 exemplar sequence exactly through the blob encoding', () async {
    final id = await repo.createSign(label: 'yes', spokenText: 'yes', threshold: 0.5);
    final original = [
      for (var i = 0; i < 32; i++) Float32List.fromList([for (var d = 0; d < 129; d++) i * 129.0 + d]),
    ];
    await repo.addExemplar(id, original);

    final stored = await repo.exemplarsFor(id);
    expect(stored, hasLength(1));
    final roundTripped = stored.single;
    expect(roundTripped, hasLength(32), reason: 'should reshape back into 32 frames, not stay flat');
    for (var i = 0; i < 32; i++) {
      expect(roundTripped[i], orderedEquals(original[i]), reason: 'frame $i differs after round-tripping');
    }
  });

  test('only enabled signs are returned for DTW matching', () async {
    final enabledId = await repo.createSign(label: 'on', spokenText: 'on', threshold: 0.5);
    final disabledId = await repo.createSign(label: 'off', spokenText: 'off', threshold: 0.5);
    await repo.addExemplar(enabledId, _sequence(0.0));
    await repo.addExemplar(disabledId, _sequence(0.0));
    await repo.setEnabled(disabledId, false);

    final result = await repo.enabledSignsWithExemplars();
    expect(result.keys.map((s) => s.label), ['on']);
  });

  test('updates spokenText and threshold independently', () async {
    final id = await repo.createSign(label: 'water', spokenText: 'water', threshold: 0.5);

    await repo.updateSpokenText(id, 'H2O');
    await repo.updateThreshold(id, 0.8);

    final sign = (await repo.allSigns()).single.sign;
    expect(sign.spokenText, 'H2O');
    expect(sign.threshold, 0.8);
    expect(sign.label, 'water', reason: 'label should be untouched by these updates');
  });

  test('deleting a sign also deletes its exemplars (cascade)', () async {
    final id = await repo.createSign(label: 'bye', spokenText: 'bye', threshold: 0.5);
    await repo.addExemplar(id, _sequence(0.0));

    await repo.deleteSign(id);

    expect(await repo.allSigns(), isEmpty);
    final orphaned = await db.select(db.exemplars).get();
    expect(orphaned, isEmpty, reason: 'exemplars should cascade-delete with their sign');
  });
}
