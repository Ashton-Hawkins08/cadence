import 'package:drift/drift.dart';
import 'package:cadence/core/constants/app_constants.dart';
import 'package:cadence/data/database/app_database.dart';

class HistoryRepository {
  final AppDatabase _db;
  const HistoryRepository(this._db);

  Stream<List<HistoryEntry>> watchRecent() {
    return (_db.select(_db.historyEntries)
          ..orderBy([(h) => OrderingTerm.desc(h.date)])
          ..limit(AppConstants.maxHistory))
        .watch();
  }

  Future<List<HistoryEntry>> getRecent() {
    return (_db.select(_db.historyEntries)
          ..orderBy([(h) => OrderingTerm.desc(h.date)])
          ..limit(AppConstants.maxHistory))
        .get();
  }

  Future<void> addEntry({
    required int? exerciseId,
    required String exerciseName,
    required int minutes,
    required int bpm,
    required String note,
  }) async {
    await _db.into(_db.historyEntries).insert(
          HistoryEntriesCompanion.insert(
            exerciseId: Value(exerciseId),
            exerciseName: exerciseName,
            date: DateTime.now(),
            minutes: minutes,
            bpm: bpm,
            note: Value(note),
          ),
        );
    await _pruneOldEntries();
  }

  Future<void> deleteAll() {
    return _db.delete(_db.historyEntries).go();
  }

  Future<void> _pruneOldEntries() async {
    await _db.customStatement(
      'DELETE FROM history_entries WHERE id NOT IN '
      '(SELECT id FROM history_entries ORDER BY date DESC LIMIT ?)',
      [AppConstants.maxHistory],
    );
  }
}
