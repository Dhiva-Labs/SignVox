import 'package:drift/drift.dart';

import 'db.dart';

/// CRUD for spoken-sentence history and quick phrases (PLAN.md §4 screens
/// 4/6, §7 `history`/`phrases` tables). History logs full utterances
/// (Speak-all, a spoken quick phrase) — not each individual word/sign
/// auto-spoken while live signing, which would flood it.
class HistoryRepository {
  HistoryRepository(this._db);

  final AppDatabase _db;

  Future<void> addEntry(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await _db
        .into(_db.historyEntries)
        .insert(HistoryEntriesCompanion.insert(spokenText: trimmed));
  }

  Future<List<HistoryEntry>> allEntries() {
    // spokenAt alone isn't a reliable "most recent first" order: SQLite's
    // CURRENT_TIMESTAMP default has one-second resolution, so two entries
    // added within the same second tie and fall back to an unspecified
    // order. `id` (autoincrement) always matches true insertion order.
    return (_db.select(_db.historyEntries)..orderBy([
          (h) => OrderingTerm.desc(h.spokenAt),
          (h) => OrderingTerm.desc(h.id),
        ]))
        .get();
  }

  Future<void> deleteEntry(int id) {
    return (_db.delete(_db.historyEntries)..where((h) => h.id.equals(id))).go();
  }

  Future<void> clearAll() {
    return _db.delete(_db.historyEntries).go();
  }

  Future<List<Phrase>> allPhrases() {
    return (_db.select(
      _db.phrases,
    )..orderBy([(p) => OrderingTerm.asc(p.sortOrder)])).get();
  }

  Future<int> addPhrase(String text) async {
    final trimmed = text.trim();
    final existing = await allPhrases();
    final nextOrder = existing.isEmpty
        ? 0
        : existing.map((p) => p.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    return _db
        .into(_db.phrases)
        .insert(
          PhrasesCompanion.insert(
            phraseText: trimmed,
            sortOrder: Value(nextOrder),
          ),
        );
  }

  Future<void> updatePhrase(int id, String text) {
    return (_db.update(_db.phrases)..where((p) => p.id.equals(id))).write(
      PhrasesCompanion(phraseText: Value(text.trim())),
    );
  }

  Future<void> deletePhrase(int id) {
    return (_db.delete(_db.phrases)..where((p) => p.id.equals(id))).go();
  }
}
