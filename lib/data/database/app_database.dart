import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:cadence/core/utils/uuid.dart';

part 'app_database.g.dart';

// ─── Sync columns (v9) ────────────────────────────────────────────────────────
//
// Cloud-sync groundwork: every syncable row carries
//   • syncId    — RFC-4122 UUID minted at creation. Local auto-increment ids
//                 differ across devices; the syncId is the row's global
//                 identity in the cloud (Firestore document id).
//   • updatedAt — ms-since-epoch last-write clock for last-write-wins merge.
//                 Set on insert via clientDefault; the sync layer bumps it on
//                 every update it pushes.
//
// Migrated v8 databases get these via ALTER TABLE with a SQL default and a
// backfill UPDATE (see the v9 migration step); fresh installs get them from
// the declarations below. Uniqueness of syncId is enforced by explicit
// indexes (_createSyncIndexes) because SQLite cannot add a UNIQUE constraint
// through ALTER TABLE.
mixin SyncColumns on Table {
  TextColumn get syncId => text().clientDefault(uuidV4)();
  IntColumn get updatedAt => integer()
      .clientDefault(() => DateTime.now().millisecondsSinceEpoch)();
}

// ─── Tables ───────────────────────────────────────────────────────────────────

class Categories extends Table with SyncColumns {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(max: 40)();
  DateTimeColumn get createdAt => dateTime()();
}

class Exercises extends Table with SyncColumns {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(max: 40)();
  IntColumn get categoryId => integer().nullable()();
  IntColumn get timesPracticed => integer().withDefault(const Constant(0))();
  IntColumn get totalMinutes => integer().withDefault(const Constant(0))();
  IntColumn get highestBpm => integer().withDefault(const Constant(0))();
  IntColumn get lastBpm => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastPracticed => dateTime().nullable()();
  IntColumn get reminderDays => integer().withDefault(const Constant(3))();
  IntColumn get goalBpm => integer().nullable()();
  IntColumn get initialBpm => integer().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  BoolColumn get archivedIndividually => boolean().withDefault(const Constant(false))();
  IntColumn get archivedCategoryBundleId => integer().nullable()();
}

class BpmLogs extends Table with SyncColumns {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId => integer()();
  IntColumn get bpm => integer()();
  DateTimeColumn get loggedAt => dateTime()();
}

class ExerciseNotes extends Table with SyncColumns {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId => integer()();
  TextColumn get noteText => text().withLength(max: 300)();
  DateTimeColumn get createdAt => dateTime()();
}

class CategoryNotes extends Table with SyncColumns {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer()();
  TextColumn get noteText => text().withLength(max: 300)();
  DateTimeColumn get createdAt => dateTime()();
}

class HistoryEntries extends Table with SyncColumns {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId => integer().nullable()();
  TextColumn get exerciseName => text()();
  DateTimeColumn get date => dateTime()();
  IntColumn get minutes => integer()();
  IntColumn get bpm => integer()();
  TextColumn get note => text().withDefault(const Constant(''))();
}

class ArchivedCategoryBundles extends Table with SyncColumns {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get archivedAt => dateTime()();
}

// ─── Calendar Tables ──────────────────────────────────────────────────────────

class CalendarEvents extends Table with SyncColumns {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(max: 80)();
  TextColumn get notes => text().withDefault(const Constant(''))();
  // Stored as UTC midnight of the local date
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  // ARGB int — null means use theme primary color
  IntColumn get colorValue => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

class EventReminders extends Table with SyncColumns {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get eventId => integer()();
  // 0 = same day, 1 = 1 day before, 7 = 1 week before, etc.
  IntColumn get daysBefore => integer()();
  // Only set when daysBefore == -1 (custom date mode)
  DateTimeColumn get customDate => dateTime().nullable()();
}

// ─── Metronome / Piece Builder Tables ────────────────────────────────────────

class MetronomePieces extends Table with SyncColumns {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(max: 100)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get modifiedAt => dateTime()();
  BoolColumn get isArchived =>
      boolean().withDefault(const Constant(false))();
  // The exercise this piece map belongs to (v8+); null = legacy standalone.
  IntColumn get exerciseId => integer().nullable()();
}

class PieceSections extends Table with SyncColumns {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get pieceId => integer()();
  IntColumn get sortOrder => integer()();
  IntColumn get startMeasure => integer()();
  IntColumn get endMeasure => integer()();
  IntColumn get bpm => integer()();
  TextColumn get timeSignature => text()(); // MetronomeTimeSignature.name
  TextColumn get subdivision => text()();   // MetronomeSubdivision.name
  BoolColumn get accentFirstBeat =>
      boolean().withDefault(const Constant(true))();
}

// ─── Sheet Music Vault ────────────────────────────────────────────────────────
//
// Score folders hold imported page images plus everything the rehearsal
// canvas needs: vector annotations (serialized stroke JSON — never bitmaps),
// measure-triggered page turns, and an optional link to a MetronomePiece
// whose section roadmap drives tempo/time-signature changes during playback.
//
// Since v8, scores and pieces belong to EXERCISES: a folder/piece carries the
// exerciseId it was attached to (via Add Exercise → Attach Sheet Music /
// Measure Tracking). Rows with a null exerciseId are legacy standalone items.

class ScoreFolders extends Table with SyncColumns {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(max: 100)();
  // Optional link to a MetronomePieces row — the piece map for this score.
  IntColumn get linkedPieceId => integer().nullable()();
  // The exercise this score belongs to (v8+).
  IntColumn get exerciseId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

class ScorePages extends Table with SyncColumns {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get folderId => integer()();
  IntColumn get sortOrder => integer()();
  TextColumn get name => text().withLength(max: 60)();
  // Absolute path of the copied image inside app documents (scores/f<id>/…)
  TextColumn get imagePath => text()();
}

class ScorePageTurns extends Table with SyncColumns {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get folderId => integer()();
  // When the metronome's measure counter reaches [measure], the viewer
  // animates to [pageIndex] (0-based position in the folder's sort order).
  IntColumn get measure => integer()();
  IntColumn get pageIndex => integer()();
}

class ScoreAnnotations extends Table with SyncColumns {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get pageId => integer()();
  // JSON array of vector strokes in image-normalized coordinates.
  // See ScoreStroke in domain/models/score_annotation.dart.
  TextColumn get strokesJson => text()();
}

// ─── Sync infrastructure (v9) ─────────────────────────────────────────────────

// Deletion tombstones. Local deletes stay hard deletes (queries never need
// deleted-row filters); each delete also records (table, syncId) here so the
// sync layer can propagate the deletion to the cloud and other devices.
// Rows are pruned once every registered device has acknowledged them.
class SyncTombstones extends Table {
  IntColumn get id => integer().autoIncrement()();
  // ('tableName' would collide with drift's Table.tableName getter.)
  TextColumn get targetTable => text()();
  TextColumn get rowSyncId => text()();
  IntColumn get deletedAt => integer()
      .clientDefault(() => DateTime.now().millisecondsSinceEpoch)();
}

// Key-value store for sync bookkeeping (last push/pull timestamps, device
// id, signed-in uid) — one place, no SharedPreferences round-trips.
class SyncState extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// ─── Database ─────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [
  Categories,
  Exercises,
  BpmLogs,
  ExerciseNotes,
  CategoryNotes,
  HistoryEntries,
  ArchivedCategoryBundles,
  CalendarEvents,
  EventReminders,
  MetronomePieces,
  PieceSections,
  ScoreFolders,
  ScorePages,
  ScorePageTurns,
  ScoreAnnotations,
  SyncTombstones,
  SyncState,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 9;

  // Every table that carries SyncColumns — used by the v9 migration and the
  // sync-id unique indexes. SQL (snake_case) names.
  static const _syncedTables = [
    'categories',
    'exercises',
    'bpm_logs',
    'exercise_notes',
    'category_notes',
    'history_entries',
    'archived_category_bundles',
    'calendar_events',
    'event_reminders',
    'metronome_pieces',
    'piece_sections',
    'score_folders',
    'score_pages',
    'score_page_turns',
    'score_annotations',
  ];

  // SQLite's ALTER TABLE cannot add UNIQUE columns, so syncId uniqueness is
  // enforced by explicit indexes created on both fresh installs and upgrades.
  Future<void> _createSyncIndexes() async {
    for (final t in _syncedTables) {
      await customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_${t}_sync_id '
          'ON $t (sync_id)');
    }
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createSyncIndexes();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(calendarEvents);
            await m.createTable(eventReminders);
          }
          if (from < 3) {
            await m.createTable(metronomePieces);
            await m.createTable(pieceSections);
          }
          if (from >= 3 && from < 4) {
            await m.addColumn(metronomePieces, metronomePieces.isArchived);
            await m.addColumn(pieceSections, pieceSections.accentFirstBeat);
          }
          if (from < 5) {
            await m.createTable(categoryNotes);
          }
          // v6 briefly introduced an audit_sessions table (practice audit
          // log, removed in v8) — the v6 create step is gone; the v8 drop
          // below cleans it up for any database that got it.
          if (from < 7) {
            await m.createTable(scoreFolders);
            await m.createTable(scorePages);
            await m.createTable(scorePageTurns);
            await m.createTable(scoreAnnotations);
          }
          if (from < 8) {
            await customStatement('DROP TABLE IF EXISTS audit_sessions');
            // addColumn only when the table PRE-DATES this run — createTable
            // above already builds new tables with exerciseId included.
            if (from >= 3) {
              await m.addColumn(metronomePieces, metronomePieces.exerciseId);
            }
            if (from >= 7) {
              await m.addColumn(scoreFolders, scoreFolders.exerciseId);
            }
          }
          if (from < 9) {
            // Cloud-sync groundwork: global row identity + last-write clock
            // on every syncable table. ALTER TABLE needs a SQL default for
            // NOT NULL columns; real values are backfilled immediately —
            // a proper UUIDv4 per row, minted inside SQLite (randomblob),
            // and updatedAt = "now".
            for (final t in _syncedTables) {
              await customStatement(
                  "ALTER TABLE $t ADD COLUMN sync_id TEXT NOT NULL DEFAULT ''");
              await customStatement(
                  'ALTER TABLE $t ADD COLUMN updated_at INTEGER NOT NULL '
                  'DEFAULT 0');
              await customStatement(
                  "UPDATE $t SET sync_id = lower("
                  "hex(randomblob(4)) || '-' || hex(randomblob(2)) || '-4' || "
                  "substr(hex(randomblob(2)), 2) || '-' || "
                  "substr('89ab', (abs(random()) % 4) + 1, 1) || "
                  "substr(hex(randomblob(2)), 2) || '-' || hex(randomblob(6)))");
              await customStatement(
                  "UPDATE $t SET updated_at = "
                  "CAST(strftime('%s', 'now') AS INTEGER) * 1000");
            }
            await m.createTable(syncTombstones);
            await m.createTable(syncState);
            await _createSyncIndexes();
          }
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'cadence_db');
  }
}
