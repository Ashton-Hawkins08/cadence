import 'package:drift/drift.dart';
import 'package:cadence/data/database/app_database.dart';
// ExercisesCompanion is generated in app_database.g.dart

class CategoryRepository {
  final AppDatabase _db;
  const CategoryRepository(this._db);

  // ── Active categories ─────────────────────────────────────────────────────

  Stream<List<Category>> watchAll() {
    return (_db.select(_db.categories)
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .watch();
  }

  Future<List<Category>> getAll() {
    return (_db.select(_db.categories)
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .get();
  }

  Future<Category?> getById(int id) {
    return (_db.select(_db.categories)
          ..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }

  Future<Category?> getByName(String name) {
    return (_db.select(_db.categories)
          ..where((c) => c.name.lower().equals(name.toLowerCase())))
        .getSingleOrNull();
  }

  Future<int> create(String name) {
    return _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            name: name,
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<void> rename(int id, String newName) {
    return (_db.update(_db.categories)..where((c) => c.id.equals(id)))
        .write(CategoriesCompanion(name: Value(newName)));
  }

  Future<void> delete(int id) async {
    final category = await getById(id);
    await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
    if (category != null) {
      await _db.tombstone('categories', [category.syncId]);
    }
  }

  // Delete a category and archive its active exercises as a bundle.
  // Exercises that were already individually archived stay that way — they
  // just lose the dangling categoryId reference but remain in the Exercises tab.
  Future<void> deleteWithBundle(int categoryId, String categoryName) async {
    // Only active (non-individually-archived) exercises belong in the bundle
    final activeExercises = await (_db.select(_db.exercises)
          ..where((e) =>
              e.categoryId.equals(categoryId) &
              e.archivedIndividually.equals(false)))
        .get();

    if (activeExercises.isNotEmpty) {
      final bundleId = await createBundle(categoryName);
      await (_db.update(_db.exercises)
            ..where((e) =>
                e.categoryId.equals(categoryId) &
                e.archivedIndividually.equals(false)))
          .write(ExercisesCompanion(
        isArchived: const Value(true),
        archivedIndividually: const Value(false),
        archivedCategoryBundleId: Value(bundleId),
      ));
    }

    // Individually-archived exercises: clear the dangling categoryId only
    await (_db.update(_db.exercises)
          ..where((e) =>
              e.categoryId.equals(categoryId) &
              e.archivedIndividually.equals(true)))
        .write(const ExercisesCompanion(
      categoryId: Value(null),
    ));

    await deleteNotesForCategory(categoryId);
    await delete(categoryId);
  }

  // Restore a bundle as a live category: find-or-create the category by name,
  // reassign all bundle exercises into it, then delete the bundle record.
  Future<void> restoreBundleAsCategory(
      int bundleId, String bundleName) async {
    final existing = await getByName(bundleName);
    final categoryId =
        existing != null ? existing.id : await create(bundleName);

    await (_db.update(_db.exercises)
          ..where((e) => e.archivedCategoryBundleId.equals(bundleId)))
        .write(ExercisesCompanion(
      isArchived: const Value(false),
      archivedIndividually: const Value(false),
      archivedCategoryBundleId: const Value(null),
      categoryId: Value(categoryId),
    ));

    await deleteBundle(bundleId);
  }

  // Delete a bundle record only (exercises already restored separately)
  // deleteBundle is already defined above

  // Permanently delete a bundle and all its archived exercises (with related data)
  Future<void> deleteBundleWithExercises(int bundleId) async {
    final exercises = await (_db.select(_db.exercises)
          ..where((e) => e.archivedCategoryBundleId.equals(bundleId)))
        .get();
    if (exercises.isNotEmpty) {
      final ids = exercises.map((e) => e.id).toList();
      final bpmSyncIds = await (_db.selectOnly(_db.bpmLogs)
            ..addColumns([_db.bpmLogs.syncId])
            ..where(_db.bpmLogs.exerciseId.isIn(ids)))
          .map((r) => r.read(_db.bpmLogs.syncId)!)
          .get();
      final noteSyncIds = await (_db.selectOnly(_db.exerciseNotes)
            ..addColumns([_db.exerciseNotes.syncId])
            ..where(_db.exerciseNotes.exerciseId.isIn(ids)))
          .map((r) => r.read(_db.exerciseNotes.syncId)!)
          .get();
      await (_db.delete(_db.bpmLogs)
            ..where((b) => b.exerciseId.isIn(ids)))
          .go();
      await (_db.delete(_db.exerciseNotes)
            ..where((n) => n.exerciseId.isIn(ids)))
          .go();
      await _db.tombstone('bpm_logs', bpmSyncIds);
      await _db.tombstone('exercise_notes', noteSyncIds);
      await _db.tombstone(
          'exercises', exercises.map((e) => e.syncId));
    }
    await (_db.delete(_db.exercises)
          ..where((e) => e.archivedCategoryBundleId.equals(bundleId)))
        .go();
    await deleteBundle(bundleId);
  }

  // ── Archived category bundles ─────────────────────────────────────────────

  Stream<List<ArchivedCategoryBundle>> watchArchived() {
    return (_db.select(_db.archivedCategoryBundles)
          ..orderBy([(a) => OrderingTerm.desc(a.archivedAt)]))
        .watch();
  }

  Future<List<ArchivedCategoryBundle>> getArchived() {
    return (_db.select(_db.archivedCategoryBundles)
          ..orderBy([(a) => OrderingTerm.desc(a.archivedAt)]))
        .get();
  }

  Future<ArchivedCategoryBundle?> getArchivedByName(String name) {
    return (_db.select(_db.archivedCategoryBundles)
          ..where((a) => a.name.lower().equals(name.toLowerCase())))
        .getSingleOrNull();
  }

  Future<int> createBundle(String name) {
    return _db.into(_db.archivedCategoryBundles).insert(
          ArchivedCategoryBundlesCompanion.insert(
            name: name,
            archivedAt: DateTime.now(),
          ),
        );
  }

  Future<void> deleteBundle(int id) async {
    final bundle = await (_db.select(_db.archivedCategoryBundles)
          ..where((a) => a.id.equals(id)))
        .getSingleOrNull();
    await (_db.delete(_db.archivedCategoryBundles)
          ..where((a) => a.id.equals(id)))
        .go();
    if (bundle != null) {
      await _db.tombstone('archived_category_bundles', [bundle.syncId]);
    }
  }

  // Bulk wipes (full data reset) — deliberately not tombstoned; see
  // AppDatabase.tombstone.
  Future<void> deleteAll() {
    return _db.delete(_db.categories).go();
  }

  Future<void> deleteAllBundles() {
    return _db.delete(_db.archivedCategoryBundles).go();
  }

  // ── Category Notes ────────────────────────────────────────────────────────

  Stream<List<CategoryNote>> watchNotes(int categoryId) {
    return (_db.select(_db.categoryNotes)
          ..where((n) => n.categoryId.equals(categoryId))
          ..orderBy([(n) => OrderingTerm.desc(n.createdAt)]))
        .watch();
  }

  Future<void> addNote(int categoryId, String text) {
    return _db.into(_db.categoryNotes).insert(
          CategoryNotesCompanion.insert(
            categoryId: categoryId,
            noteText: text,
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<void> deleteNote(int noteId) async {
    final note = await (_db.select(_db.categoryNotes)
          ..where((n) => n.id.equals(noteId)))
        .getSingleOrNull();
    await (_db.delete(_db.categoryNotes)
          ..where((n) => n.id.equals(noteId)))
        .go();
    if (note != null) await _db.tombstone('category_notes', [note.syncId]);
  }

  Future<void> deleteNotesForCategory(int categoryId) async {
    final syncIds = await (_db.selectOnly(_db.categoryNotes)
          ..addColumns([_db.categoryNotes.syncId])
          ..where(_db.categoryNotes.categoryId.equals(categoryId)))
        .map((r) => r.read(_db.categoryNotes.syncId)!)
        .get();
    await (_db.delete(_db.categoryNotes)
          ..where((n) => n.categoryId.equals(categoryId)))
        .go();
    await _db.tombstone('category_notes', syncIds);
  }

  // Bulk wipe (full data reset) — deliberately not tombstoned; see
  // AppDatabase.tombstone.
  Future<void> deleteAllCategoryNotes() {
    return _db.delete(_db.categoryNotes).go();
  }
}
