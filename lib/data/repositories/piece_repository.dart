import 'package:drift/drift.dart';
import 'package:cadence/data/database/app_database.dart';

class PieceRepository {
  final AppDatabase _db;
  const PieceRepository(this._db);

  // ── Active pieces ─────────────────────────────────────────────────────────

  Stream<List<MetronomePiece>> watchAll() {
    return (_db.select(_db.metronomePieces)
          ..where((p) => p.isArchived.equals(false))
          ..orderBy([(p) => OrderingTerm.desc(p.modifiedAt)]))
        .watch();
  }

  Stream<List<MetronomePiece>> watchArchived() {
    return (_db.select(_db.metronomePieces)
          ..where((p) => p.isArchived.equals(true))
          ..orderBy([(p) => OrderingTerm.desc(p.modifiedAt)]))
        .watch();
  }

  Future<MetronomePiece?> getById(int id) {
    return (_db.select(_db.metronomePieces)..where((p) => p.id.equals(id)))
        .getSingleOrNull();
  }

  Future<int> create(String title, {int? exerciseId}) {
    final now = DateTime.now();
    return _db.into(_db.metronomePieces).insert(
          MetronomePiecesCompanion.insert(
            title: title,
            createdAt: now,
            modifiedAt: now,
            exerciseId: Value(exerciseId),
          ),
        );
  }

  /// The piece map attached to an exercise (one per exercise by convention).
  Future<MetronomePiece?> getPieceForExercise(int exerciseId) {
    return (_db.select(_db.metronomePieces)
          ..where((p) => p.exerciseId.equals(exerciseId))
          ..where((p) => p.isArchived.equals(false))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> rename(int id, String title) {
    return (_db.update(_db.metronomePieces)..where((p) => p.id.equals(id)))
        .write(MetronomePiecesCompanion(
      title: Value(title),
      modifiedAt: Value(DateTime.now()),
    ));
  }

  Future<void> archive(int id) {
    return (_db.update(_db.metronomePieces)..where((p) => p.id.equals(id)))
        .write(const MetronomePiecesCompanion(isArchived: Value(true)));
  }

  Future<void> restore(int id) {
    return (_db.update(_db.metronomePieces)..where((p) => p.id.equals(id)))
        .write(const MetronomePiecesCompanion(isArchived: Value(false)));
  }

  Future<void> touchModified(int id) {
    return (_db.update(_db.metronomePieces)..where((p) => p.id.equals(id)))
        .write(MetronomePiecesCompanion(modifiedAt: Value(DateTime.now())));
  }

  Future<void> delete(int id) async {
    late List<String> sectionSyncIds;
    late String? pieceSyncId;
    await _db.transaction(() async {
      sectionSyncIds = await (_db.selectOnly(_db.pieceSections)
            ..addColumns([_db.pieceSections.syncId])
            ..where(_db.pieceSections.pieceId.equals(id)))
          .map((r) => r.read(_db.pieceSections.syncId)!)
          .get();
      pieceSyncId = (await getById(id))?.syncId;
      await (_db.delete(_db.pieceSections)
            ..where((s) => s.pieceId.equals(id)))
          .go();
      await (_db.delete(_db.metronomePieces)..where((p) => p.id.equals(id)))
          .go();
    });
    await _db.tombstone('piece_sections', sectionSyncIds);
    if (pieceSyncId != null) {
      await _db.tombstone('metronome_pieces', [pieceSyncId!]);
    }
  }

  // Bulk wipe (full data reset) — deliberately not tombstoned; see
  // AppDatabase.tombstone.
  Future<void> deleteAll() async {
    await _db.delete(_db.pieceSections).go();
    await _db.delete(_db.metronomePieces).go();
  }

  // ── Sections ──────────────────────────────────────────────────────────────

  Future<List<PieceSection>> getSectionsForPiece(int pieceId) {
    return (_db.select(_db.pieceSections)
          ..where((s) => s.pieceId.equals(pieceId))
          ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
        .get();
  }

  Stream<List<PieceSection>> watchSectionsForPiece(int pieceId) {
    return (_db.select(_db.pieceSections)
          ..where((s) => s.pieceId.equals(pieceId))
          ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
        .watch();
  }

  Future<void> replaceSections(
      int pieceId, List<PieceSectionsCompanion> sections) async {
    late List<String> oldSyncIds;
    await _db.transaction(() async {
      oldSyncIds = await (_db.selectOnly(_db.pieceSections)
            ..addColumns([_db.pieceSections.syncId])
            ..where(_db.pieceSections.pieceId.equals(pieceId)))
          .map((r) => r.read(_db.pieceSections.syncId)!)
          .get();
      await (_db.delete(_db.pieceSections)
            ..where((s) => s.pieceId.equals(pieceId)))
          .go();
      for (final s in sections) {
        await _db.into(_db.pieceSections).insert(s);
      }
    });
    await _db.tombstone('piece_sections', oldSyncIds);
    await touchModified(pieceId);
  }

  Future<int> duplicate(int sourceId, String newTitle) async {
    final sections = await getSectionsForPiece(sourceId);
    return _db.transaction(() async {
      final now = DateTime.now();
      final newId = await _db.into(_db.metronomePieces).insert(
            MetronomePiecesCompanion.insert(
              title: newTitle,
              createdAt: now,
              modifiedAt: now,
            ),
          );
      for (final s in sections) {
        await _db.into(_db.pieceSections).insert(
              PieceSectionsCompanion.insert(
                pieceId: newId,
                sortOrder: s.sortOrder,
                startMeasure: s.startMeasure,
                endMeasure: s.endMeasure,
                bpm: s.bpm,
                timeSignature: s.timeSignature,
                subdivision: s.subdivision,
                accentFirstBeat: Value(s.accentFirstBeat),
              ),
            );
      }
      return newId;
    });
  }
}
