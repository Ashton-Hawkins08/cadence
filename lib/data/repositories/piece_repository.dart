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

  Future<int> create(String title) {
    final now = DateTime.now();
    return _db.into(_db.metronomePieces).insert(
          MetronomePiecesCompanion.insert(
            title: title,
            createdAt: now,
            modifiedAt: now,
          ),
        );
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

  Future<void> delete(int id) {
    return _db.transaction(() async {
      await (_db.delete(_db.pieceSections)
            ..where((s) => s.pieceId.equals(id)))
          .go();
      await (_db.delete(_db.metronomePieces)..where((p) => p.id.equals(id)))
          .go();
    });
  }

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
    await _db.transaction(() async {
      await (_db.delete(_db.pieceSections)
            ..where((s) => s.pieceId.equals(pieceId)))
          .go();
      for (final s in sections) {
        await _db.into(_db.pieceSections).insert(s);
      }
    });
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
