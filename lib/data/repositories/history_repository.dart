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

  // Bulk wipe (full data reset) — deliberately not tombstoned; see
  // AppDatabase.tombstone.
  Future<void> deleteAll() {
    return _db.delete(_db.historyEntries).go();
  }

  // Rewritten from a raw "DELETE ... WHERE id NOT IN (...)" statement: that
  // version had no way to know WHICH rows it had just pruned, so the ongoing
  // 50-entry cap silently dropped entries with no tombstone — they would
  // have resurrected on the next cloud restore.
  Future<void> _pruneOldEntries() async {
    final keepIds = await (_db.select(_db.historyEntries)
          ..orderBy([(h) => OrderingTerm.desc(h.date)])
          ..limit(AppConstants.maxHistory))
        .map((h) => h.id)
        .get();
    final toPrune = await (_db.select(_db.historyEntries)
          ..where((h) => h.id.isNotIn(keepIds)))
        .get();
    if (toPrune.isEmpty) return;
    await (_db.delete(_db.historyEntries)..where((h) => h.id.isNotIn(keepIds)))
        .go();
    await _db.tombstone('history_entries', toPrune.map((h) => h.syncId));
  }
}
