import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'db.g.dart';

/// Taught signs (PLAN.md §7). [threshold] is the DTW acceptance cutoff
/// computed at teach time from exemplar spread (§6.3); [spokenText] lets a
/// sign's label differ from what TTS actually says (e.g. "coffee-2hand"
/// speaks "coffee").
class Signs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get label => text()();
  TextColumn get spokenText => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  RealColumn get threshold => real()();
  IntColumn get sampleCount => integer().withDefault(const Constant(0))();
}

/// One recorded sample for a sign: a resampled 32x129 float32 sequence
/// (§6.3), stored as a raw little-endian blob (16512 bytes).
///
/// Column names below deliberately avoid drift's own DSL builder names
/// (`text()`, `blob()`, ...) — a column getter named the same as the
/// builder it calls (e.g. `blob => blob()()`) confuses drift_dev's static
/// analysis into treating the call as self-referential (hit during P5).
class Exemplars extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get signId =>
      integer().references(Signs, #id, onDelete: KeyAction.cascade)();
  BlobColumn get landmarkSequence => blob()();
  DateTimeColumn get recordedAt => dateTime().withDefault(currentDateAndTime)();
}

class HistoryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get spokenText => text()();
  DateTimeColumn get spokenAt => dateTime().withDefault(currentDateAndTime)();
}

class Phrases extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get phraseText => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DriftDatabase(tables: [Signs, Exemplars, HistoryEntries, Phrases])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For unit tests — pass an in-memory `NativeDatabase.memory()` executor.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  // SQLite has foreign keys OFF by default per-connection — without this,
  // Exemplars.signId's onDelete: cascade (above) is silently a no-op and
  // deleting a sign leaves its exemplars orphaned (caught by a P5 unit test).
  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'sign_vox',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    );
  }
}
