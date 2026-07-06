import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

// ─── Tables ───────────────────────────────────────────────────────────────────

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(max: 40)();
  DateTimeColumn get createdAt => dateTime()();
}

class Exercises extends Table {
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

class BpmLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId => integer()();
  IntColumn get bpm => integer()();
  DateTimeColumn get loggedAt => dateTime()();
}

class ExerciseNotes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId => integer()();
  TextColumn get noteText => text().withLength(max: 300)();
  DateTimeColumn get createdAt => dateTime()();
}

class CategoryNotes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer()();
  TextColumn get noteText => text().withLength(max: 300)();
  DateTimeColumn get createdAt => dateTime()();
}

class HistoryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId => integer().nullable()();
  TextColumn get exerciseName => text()();
  DateTimeColumn get date => dateTime()();
  IntColumn get minutes => integer()();
  IntColumn get bpm => integer()();
  TextColumn get note => text().withDefault(const Constant(''))();
}

class ArchivedCategoryBundles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get archivedAt => dateTime()();
}

// ─── Calendar Tables ──────────────────────────────────────────────────────────

class CalendarEvents extends Table {
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

class EventReminders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get eventId => integer()();
  // 0 = same day, 1 = 1 day before, 7 = 1 week before, etc.
  IntColumn get daysBefore => integer()();
  // Only set when daysBefore == -1 (custom date mode)
  DateTimeColumn get customDate => dateTime().nullable()();
}

// ─── Metronome / Piece Builder Tables ────────────────────────────────────────

class MetronomePieces extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(max: 100)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get modifiedAt => dateTime()();
  BoolColumn get isArchived =>
      boolean().withDefault(const Constant(false))();
  // The exercise this piece map belongs to (v8+); null = legacy standalone.
  IntColumn get exerciseId => integer().nullable()();
}

class PieceSections extends Table {
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

class ScoreFolders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(max: 100)();
  // Optional link to a MetronomePieces row — the piece map for this score.
  IntColumn get linkedPieceId => integer().nullable()();
  // The exercise this score belongs to (v8+).
  IntColumn get exerciseId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

class ScorePages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get folderId => integer()();
  IntColumn get sortOrder => integer()();
  TextColumn get name => text().withLength(max: 60)();
  // Absolute path of the copied image inside app documents (scores/f<id>/…)
  TextColumn get imagePath => text()();
}

class ScorePageTurns extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get folderId => integer()();
  // When the metronome's measure counter reaches [measure], the viewer
  // animates to [pageIndex] (0-based position in the folder's sort order).
  IntColumn get measure => integer()();
  IntColumn get pageIndex => integer()();
}

class ScoreAnnotations extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get pageId => integer()();
  // JSON array of vector strokes in image-normalized coordinates.
  // See ScoreStroke in domain/models/score_annotation.dart.
  TextColumn get strokesJson => text()();
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
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
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
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'cadence_db');
  }
}
