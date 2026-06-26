import 'package:drift/drift.dart';
import 'package:cadence/data/database/app_database.dart';

class ExerciseRepository {
  final AppDatabase _db;
  const ExerciseRepository(this._db);

  // ── Active exercises ──────────────────────────────────────────────────────

  Stream<List<Exercise>> watchActive() {
    return (_db.select(_db.exercises)
          ..where((e) => e.isArchived.equals(false))
          ..orderBy([(e) => OrderingTerm.asc(e.name)]))
        .watch();
  }

  Future<List<Exercise>> getActive() {
    return (_db.select(_db.exercises)
          ..where((e) => e.isArchived.equals(false))
          ..orderBy([(e) => OrderingTerm.asc(e.name)]))
        .get();
  }

  Future<Exercise?> getById(int id) {
    return (_db.select(_db.exercises)..where((e) => e.id.equals(id)))
        .getSingleOrNull();
  }

  Future<Exercise?> getByName(String name) {
    return (_db.select(_db.exercises)
          ..where((e) =>
              e.name.lower().equals(name.toLowerCase()) &
              e.isArchived.equals(false)))
        .getSingleOrNull();
  }

  Future<List<Exercise>> getByCategoryId(int categoryId) {
    return (_db.select(_db.exercises)
          ..where((e) =>
              e.categoryId.equals(categoryId) & e.isArchived.equals(false)))
        .get();
  }

  Future<int> create(ExercisesCompanion companion) {
    return _db.into(_db.exercises).insert(companion);
  }

  Future<void> update(int id, ExercisesCompanion companion) {
    return (_db.update(_db.exercises)..where((e) => e.id.equals(id)))
        .write(companion);
  }

  Future<void> rename(int id, String newName) {
    return (_db.update(_db.exercises)..where((e) => e.id.equals(id)))
        .write(ExercisesCompanion(name: Value(newName)));
  }

  Future<void> reassignCategory(int id, int? newCategoryId) {
    return (_db.update(_db.exercises)..where((e) => e.id.equals(id))).write(
        ExercisesCompanion(categoryId: Value(newCategoryId)));
  }

  // Reassign all exercises in a category to a new category (used on rename)
  Future<void> reassignAllInCategory(int oldCategoryId, int newCategoryId) {
    return (_db.update(_db.exercises)
          ..where((e) => e.categoryId.equals(oldCategoryId)))
        .write(ExercisesCompanion(categoryId: Value(newCategoryId)));
  }

  // ── Archive ───────────────────────────────────────────────────────────────

  Future<void> archiveIndividually(int id) {
    return (_db.update(_db.exercises)..where((e) => e.id.equals(id))).write(
      const ExercisesCompanion(
        isArchived: Value(true),
        archivedIndividually: Value(true),
      ),
    );
  }

  Future<void> archiveWithBundle(int id, int bundleId) {
    return (_db.update(_db.exercises)..where((e) => e.id.equals(id))).write(
      ExercisesCompanion(
        isArchived: const Value(true),
        archivedIndividually: const Value(false),
        archivedCategoryBundleId: Value(bundleId),
      ),
    );
  }

  Stream<List<Exercise>> watchAllArchived() {
    return (_db.select(_db.exercises)
          ..where((e) => e.isArchived.equals(true))
          ..orderBy([(e) => OrderingTerm.asc(e.name)]))
        .watch();
  }

  Future<List<Exercise>> getIndividuallyArchived() {
    return (_db.select(_db.exercises)
          ..where((e) =>
              e.isArchived.equals(true) &
              e.archivedIndividually.equals(true))
          ..orderBy([(e) => OrderingTerm.asc(e.name)]))
        .get();
  }

  Future<List<Exercise>> getArchivedInBundle(int bundleId) {
    return (_db.select(_db.exercises)
          ..where((e) => e.archivedCategoryBundleId.equals(bundleId)))
        .get();
  }

  // Restore to Uncategorized (no category)
  Future<void> restore(int id) => restoreExercise(id, null);

  Future<void> restoreBundle(int bundleId) {
    return (_db.update(_db.exercises)
          ..where((e) => e.archivedCategoryBundleId.equals(bundleId)))
        .write(const ExercisesCompanion(
          isArchived: Value(false),
          archivedIndividually: Value(false),
          archivedCategoryBundleId: Value(null),
          categoryId: Value(null),
        ));
  }

  Future<void> restoreExercise(int id, int? newCategoryId) {
    return (_db.update(_db.exercises)..where((e) => e.id.equals(id))).write(
      ExercisesCompanion(
        isArchived: const Value(false),
        archivedIndividually: const Value(false),
        archivedCategoryBundleId: const Value(null),
        categoryId: Value(newCategoryId),
      ),
    );
  }

  Future<void> permanentlyDelete(int id) async {
    await deleteBpmLogsForExercise(id);
    await deleteNotesForExercise(id);
    await (_db.delete(_db.exercises)..where((e) => e.id.equals(id))).go();
  }

  Future<void> deleteAll() {
    return _db.delete(_db.exercises).go();
  }

  // ── BPM Logs ──────────────────────────────────────────────────────────────

  Future<List<BpmLog>> getBpmLogs(int exerciseId) {
    return (_db.select(_db.bpmLogs)
          ..where((b) => b.exerciseId.equals(exerciseId))
          ..orderBy([(b) => OrderingTerm.asc(b.loggedAt)]))
        .get();
  }

  Future<List<BpmLog>> getBpmLogsForExercises(List<int> exerciseIds) {
    if (exerciseIds.isEmpty) return Future.value([]);
    return (_db.select(_db.bpmLogs)
          ..where((b) => b.exerciseId.isIn(exerciseIds)))
        .get();
  }

  Future<void> addBpmLog(int exerciseId, int bpm) {
    return _db.into(_db.bpmLogs).insert(
          BpmLogsCompanion.insert(
            exerciseId: exerciseId,
            bpm: bpm,
            loggedAt: DateTime.now(),
          ),
        );
  }

  Future<void> deleteBpmLogsForExercise(int exerciseId) {
    return (_db.delete(_db.bpmLogs)
          ..where((b) => b.exerciseId.equals(exerciseId)))
        .go();
  }

  Future<void> deleteAllBpmLogs() {
    return _db.delete(_db.bpmLogs).go();
  }

  // ── Notes ─────────────────────────────────────────────────────────────────

  Stream<List<ExerciseNote>> watchNotes(int exerciseId) {
    return (_db.select(_db.exerciseNotes)
          ..where((n) => n.exerciseId.equals(exerciseId))
          ..orderBy([(n) => OrderingTerm.desc(n.createdAt)]))
        .watch();
  }

  Future<List<ExerciseNote>> getNotes(int exerciseId) {
    return (_db.select(_db.exerciseNotes)
          ..where((n) => n.exerciseId.equals(exerciseId))
          ..orderBy([(n) => OrderingTerm.desc(n.createdAt)]))
        .get();
  }

  Future<void> addNote(int exerciseId, String text) {
    return _db.into(_db.exerciseNotes).insert(
          ExerciseNotesCompanion.insert(
            exerciseId: exerciseId,
            noteText: text,
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<void> deleteNote(int noteId) {
    return (_db.delete(_db.exerciseNotes)
          ..where((n) => n.id.equals(noteId)))
        .go();
  }

  Future<void> deleteNotesForExercise(int exerciseId) {
    return (_db.delete(_db.exerciseNotes)
          ..where((n) => n.exerciseId.equals(exerciseId)))
        .go();
  }

  Future<void> deleteAllNotes() {
    return _db.delete(_db.exerciseNotes).go();
  }
}
