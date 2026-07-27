import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign_vox/data/db.dart';
import 'package:sign_vox/data/history_repository.dart';

void main() {
  late AppDatabase db;
  late HistoryRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = HistoryRepository(db);
  });

  tearDown(() => db.close());

  test('adds entries and lists them most-recent-first', () async {
    await repo.addEntry('hello there');
    await repo.addEntry('how are you');

    final entries = await repo.allEntries();
    expect(entries, hasLength(2));
    expect(entries.first.spokenText, 'how are you');
    expect(entries.last.spokenText, 'hello there');
  });

  test('ignores blank text', () async {
    await repo.addEntry('   ');
    expect(await repo.allEntries(), isEmpty);
  });

  test('deletes a single entry and clears all', () async {
    await repo.addEntry('one');
    await repo.addEntry('two');
    final entries = await repo.allEntries();

    await repo.deleteEntry(entries.last.id);
    expect(await repo.allEntries(), hasLength(1));

    await repo.clearAll();
    expect(await repo.allEntries(), isEmpty);
  });

  test('adds phrases with increasing sort order and lists them in that order', () async {
    await repo.addPhrase('Thank you');
    await repo.addPhrase('One moment please');

    final phrases = await repo.allPhrases();
    expect(phrases.map((p) => p.phraseText), ['Thank you', 'One moment please']);
    expect(phrases[0].sortOrder, lessThan(phrases[1].sortOrder));
  });

  test('updates and deletes a phrase', () async {
    final id = await repo.addPhrase('Hi');
    await repo.updatePhrase(id, 'Hello');
    var phrases = await repo.allPhrases();
    expect(phrases.single.phraseText, 'Hello');

    await repo.deletePhrase(id);
    phrases = await repo.allPhrases();
    expect(phrases, isEmpty);
  });
}
