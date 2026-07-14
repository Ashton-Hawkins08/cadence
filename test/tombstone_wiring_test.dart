import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cadence/data/database/app_database.dart';
import 'package:cadence/data/repositories/calendar_repository.dart';
import 'package:cadence/data/repositories/category_repository.dart';
import 'package:cadence/data/repositories/exercise_repository.dart';
import 'package:cadence/data/repositories/history_repository.dart';
import 'package:cadence/data/repositories/piece_repository.dart';
import 'package:cadence/core/constants/app_constants.dart';

// CloudSyncService.backup() only propagates a deletion to the cloud if the
// deleting repository recorded a tombstone first. These tests exist because
// that wiring is easy to silently omit at any ONE of the ~20 delete call
// sites it touches — an omission here means "delete this exercise" would
// look successful locally but resurrect on the next cloud restore.

AppDatabase _makeDb() => AppDatabase(NativeDatabase.memory());

Future<Set<String>> _tombstonedSyncIds(AppDatabase db, String table) async {
  final rows = await (db.select(db.syncTombstones)
        ..where((t) => t.targetTable.equals(table)))
      .get();
  return rows.map((r) => r.rowSyncId).toSet();
}

void main() {
  late AppDatabase db;

  tearDown(() async => db.close());

  test('CategoryRepository.delete tombstones the category', () async {
    db = _makeDb();
    final repo = CategoryRepository(db);
    final id = await repo.create('Rudiments');
    final syncId = (await repo.getById(id))!.syncId;
    await repo.delete(id);
    expect(await _tombstonedSyncIds(db, 'categories'), {syncId});
  });

  test('CategoryRepository.deleteWithBundle tombstones the category', () async {
    db = _makeDb();
    final repo = CategoryRepository(db);
    final id = await repo.create('Rudiments');
    final syncId = (await repo.getById(id))!.syncId;
    await repo.deleteWithBundle(id, 'Rudiments');
    expect(await _tombstonedSyncIds(db, 'categories'), {syncId});
  });

  test('CategoryRepository note deletes are tombstoned individually and in bulk',
      () async {
    db = _makeDb();
    final repo = CategoryRepository(db);
    final catId = await repo.create('Cat');
    await repo.addNote(catId, 'note 1');
    await repo.addNote(catId, 'note 2');
    final notes = await repo.watchNotes(catId).first;
    final syncIds = notes.map((n) => n.syncId).toSet();

    await repo.deleteNote(notes.first.id);
    await repo.deleteNotesForCategory(catId);

    expect(await _tombstonedSyncIds(db, 'category_notes'), syncIds);
  });

  test('ExerciseRepository.permanentlyDelete tombstones the exercise, its '
      'bpm logs, and its notes', () async {
    db = _makeDb();
    final repo = ExerciseRepository(db);
    final id = await repo.create(ExercisesCompanion.insert(name: 'Paradiddles'));
    await repo.addBpmLog(id, 120);
    await repo.addBpmLog(id, 130);
    await repo.addNote(id, 'watch the accents');
    final exerciseSyncId = (await repo.getById(id))!.syncId;
    final bpmSyncIds =
        (await repo.getBpmLogs(id)).map((b) => b.syncId).toSet();
    final noteSyncIds =
        (await repo.getNotes(id)).map((n) => n.syncId).toSet();

    await repo.permanentlyDelete(id);

    expect(await _tombstonedSyncIds(db, 'exercises'), {exerciseSyncId});
    expect(await _tombstonedSyncIds(db, 'bpm_logs'), bpmSyncIds);
    expect(await _tombstonedSyncIds(db, 'exercise_notes'), noteSyncIds);
  });

  test('CalendarRepository.deleteEvent tombstones the event and its reminders',
      () async {
    db = _makeDb();
    final repo = CalendarRepository(db);
    final now = DateTime.now();
    final eventId = await repo.createEvent(
        title: 'Band Camp', startDate: now, endDate: now);
    await repo.addReminder(eventId, 1);
    await repo.addReminder(eventId, 7);
    final eventSyncId = (await repo.getById(eventId))!.syncId;
    final reminderSyncIds = (await repo.getRemindersForEvent(eventId))
        .map((r) => r.syncId)
        .toSet();

    await repo.deleteEvent(eventId);

    expect(await _tombstonedSyncIds(db, 'calendar_events'), {eventSyncId});
    expect(await _tombstonedSyncIds(db, 'event_reminders'), reminderSyncIds);
  });

  test('PieceRepository.delete tombstones the piece and its sections',
      () async {
    db = _makeDb();
    final repo = PieceRepository(db);
    final pieceId = await repo.create('Concert Piece');
    await repo.replaceSections(pieceId, [
      PieceSectionsCompanion.insert(
        pieceId: pieceId,
        sortOrder: 0,
        startMeasure: 1,
        endMeasure: 8,
        bpm: 90,
        timeSignature: 'sig4_4',
        subdivision: 'quarter',
      ),
    ]);
    final pieceSyncId = (await repo.getById(pieceId))!.syncId;
    final sectionSyncIds = (await repo.getSectionsForPiece(pieceId))
        .map((s) => s.syncId)
        .toSet();

    await repo.delete(pieceId);

    expect(await _tombstonedSyncIds(db, 'metronome_pieces'), {pieceSyncId});
    expect(await _tombstonedSyncIds(db, 'piece_sections'), sectionSyncIds);
  });

  test('PieceRepository.replaceSections tombstones the sections it replaces',
      () async {
    db = _makeDb();
    final repo = PieceRepository(db);
    final pieceId = await repo.create('Piece');
    await repo.replaceSections(pieceId, [
      PieceSectionsCompanion.insert(
        pieceId: pieceId,
        sortOrder: 0,
        startMeasure: 1,
        endMeasure: 4,
        bpm: 60,
        timeSignature: 'sig4_4',
        subdivision: 'quarter',
      ),
    ]);
    final oldSyncId =
        (await repo.getSectionsForPiece(pieceId)).first.syncId;

    await repo.replaceSections(pieceId, [
      PieceSectionsCompanion.insert(
        pieceId: pieceId,
        sortOrder: 0,
        startMeasure: 1,
        endMeasure: 4,
        bpm: 120,
        timeSignature: 'sig4_4',
        subdivision: 'quarter',
      ),
    ]);

    expect(await _tombstonedSyncIds(db, 'piece_sections'), {oldSyncId});
  });

  test('HistoryRepository prunes past the cap and tombstones the dropped rows',
      () async {
    db = _makeDb();
    final repo = HistoryRepository(db);
    for (var i = 0; i < AppConstants.maxHistory + 3; i++) {
      await repo.addEntry(
        exerciseId: null,
        exerciseName: 'Ex $i',
        minutes: 10,
        bpm: 100,
        note: '',
      );
    }
    final remaining = await repo.getRecent();
    expect(remaining.length, AppConstants.maxHistory);

    final tombstoned = await _tombstonedSyncIds(db, 'history_entries');
    expect(tombstoned.length, 3,
        reason: 'exactly the entries pushed past the cap must be tombstoned');
  });

  test('bulk wipes (deleteAll) do NOT write tombstones', () async {
    db = _makeDb();
    final categoryRepo = CategoryRepository(db);
    final exerciseRepo = ExerciseRepository(db);
    final catId = await categoryRepo.create('Cat');
    await exerciseRepo.create(
        ExercisesCompanion.insert(name: 'Ex', categoryId: Value(catId)));

    await categoryRepo.deleteAll();
    await exerciseRepo.deleteAll();

    final allTombstones = await db.select(db.syncTombstones).get();
    expect(allTombstones, isEmpty,
        reason: 'a local full-data reset is not a cloud-sync event');
  });
}
