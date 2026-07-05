import 'dart:io';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cadence/data/database/app_database.dart';

// ── Score vault repository ────────────────────────────────────────────────────
//
// Owns both the DB rows AND the image files. Imported images are COPIED into
// app documents (scores/f<folderId>/…) so the vault never depends on gallery
// files that the OS may move or delete; deleting a folder/page removes its
// files too.

class ScoreRepository {
  final AppDatabase _db;
  const ScoreRepository(this._db);

  // ── Folders ────────────────────────────────────────────────────────────────

  Stream<List<ScoreFolder>> watchFolders() {
    return (_db.select(_db.scoreFolders)
          ..orderBy([(f) => OrderingTerm.desc(f.createdAt)]))
        .watch();
  }

  Future<int> createFolder(String name) {
    return _db.into(_db.scoreFolders).insert(ScoreFoldersCompanion.insert(
          name: name,
          createdAt: DateTime.now(),
        ));
  }

  Future<void> renameFolder(int id, String name) {
    return (_db.update(_db.scoreFolders)..where((f) => f.id.equals(id)))
        .write(ScoreFoldersCompanion(name: Value(name)));
  }

  Future<void> setLinkedPiece(int folderId, int? pieceId) {
    return (_db.update(_db.scoreFolders)..where((f) => f.id.equals(folderId)))
        .write(ScoreFoldersCompanion(linkedPieceId: Value(pieceId)));
  }

  Future<void> deleteFolder(int folderId) async {
    final pages = await (_db.select(_db.scorePages)
          ..where((p) => p.folderId.equals(folderId)))
        .get();
    await _db.transaction(() async {
      for (final p in pages) {
        await (_db.delete(_db.scoreAnnotations)
              ..where((a) => a.pageId.equals(p.id)))
            .go();
      }
      await (_db.delete(_db.scorePages)
            ..where((p) => p.folderId.equals(folderId)))
          .go();
      await (_db.delete(_db.scorePageTurns)
            ..where((t) => t.folderId.equals(folderId)))
          .go();
      await (_db.delete(_db.scoreFolders)
            ..where((f) => f.id.equals(folderId)))
          .go();
    });
    // Files last — if the process dies mid-way the DB is already consistent
    // and orphaned files are merely wasted bytes, not broken rows.
    for (final p in pages) {
      try {
        final f = File(p.imagePath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    try {
      final dir = await _folderDir(folderId);
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  // ── Pages ──────────────────────────────────────────────────────────────────

  Stream<List<ScorePage>> watchPages(int folderId) {
    return (_db.select(_db.scorePages)
          ..where((p) => p.folderId.equals(folderId))
          ..orderBy([(p) => OrderingTerm.asc(p.sortOrder)]))
        .watch();
  }

  Future<List<ScorePage>> getPages(int folderId) {
    return (_db.select(_db.scorePages)
          ..where((p) => p.folderId.equals(folderId))
          ..orderBy([(p) => OrderingTerm.asc(p.sortOrder)]))
        .get();
  }

  static Future<Directory> _folderDir(int folderId) async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}${Platform.pathSeparator}scores'
        '${Platform.pathSeparator}f$folderId');
  }

  /// Copies [sourcePath] into the vault and registers the page.
  Future<int> addPage({
    required int folderId,
    required String sourcePath,
    required String name,
  }) async {
    final dir = await _folderDir(folderId);
    await dir.create(recursive: true);
    final ext = sourcePath.contains('.')
        ? sourcePath.substring(sourcePath.lastIndexOf('.'))
        : '.jpg';
    final dest =
        '${dir.path}${Platform.pathSeparator}p${DateTime.now().microsecondsSinceEpoch}$ext';
    await File(sourcePath).copy(dest);

    final count = await (_db.select(_db.scorePages)
          ..where((p) => p.folderId.equals(folderId)))
        .get()
        .then((l) => l.length);

    return _db.into(_db.scorePages).insert(ScorePagesCompanion.insert(
          folderId: folderId,
          sortOrder: count,
          name: name,
          imagePath: dest,
        ));
  }

  Future<void> renamePage(int id, String name) {
    return (_db.update(_db.scorePages)..where((p) => p.id.equals(id)))
        .write(ScorePagesCompanion(name: Value(name)));
  }

  Future<void> deletePage(int id) async {
    final page = await (_db.select(_db.scorePages)
          ..where((p) => p.id.equals(id)))
        .getSingleOrNull();
    if (page == null) return;
    await _db.transaction(() async {
      await (_db.delete(_db.scoreAnnotations)
            ..where((a) => a.pageId.equals(id)))
          .go();
      await (_db.delete(_db.scorePages)..where((p) => p.id.equals(id))).go();
      // Close the sortOrder gap so pageIndex-based turn triggers stay sane.
      await _db.customStatement(
        'UPDATE score_pages SET sort_order = sort_order - 1 '
        'WHERE folder_id = ? AND sort_order > ?',
        [page.folderId, page.sortOrder],
      );
    });
    try {
      final f = File(page.imagePath);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Rewrites sortOrder to match [orderedIds] (ReorderableListView result).
  Future<void> reorderPages(int folderId, List<int> orderedIds) {
    return _db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (_db.update(_db.scorePages)
              ..where((p) => p.id.equals(orderedIds[i])))
            .write(ScorePagesCompanion(sortOrder: Value(i)));
      }
    });
  }

  // ── Page turn triggers ─────────────────────────────────────────────────────

  Stream<List<ScorePageTurn>> watchTurns(int folderId) {
    return (_db.select(_db.scorePageTurns)
          ..where((t) => t.folderId.equals(folderId))
          ..orderBy([(t) => OrderingTerm.asc(t.measure)]))
        .watch();
  }

  Future<void> addTurn(int folderId, int measure, int pageIndex) {
    return _db.into(_db.scorePageTurns).insert(
        ScorePageTurnsCompanion.insert(
            folderId: folderId, measure: measure, pageIndex: pageIndex));
  }

  Future<void> deleteTurn(int id) {
    return (_db.delete(_db.scorePageTurns)..where((t) => t.id.equals(id)))
        .go();
  }

  // ── Annotations ────────────────────────────────────────────────────────────

  Future<String> getAnnotationJson(int pageId) async {
    final row = await (_db.select(_db.scoreAnnotations)
          ..where((a) => a.pageId.equals(pageId)))
        .getSingleOrNull();
    return row?.strokesJson ?? '';
  }

  Future<void> saveAnnotationJson(int pageId, String json) async {
    await _db.transaction(() async {
      final existing = await (_db.select(_db.scoreAnnotations)
            ..where((a) => a.pageId.equals(pageId)))
          .getSingleOrNull();
      if (existing == null) {
        await _db.into(_db.scoreAnnotations).insert(
            ScoreAnnotationsCompanion.insert(
                pageId: pageId, strokesJson: json));
      } else {
        await (_db.update(_db.scoreAnnotations)
              ..where((a) => a.id.equals(existing.id)))
            .write(ScoreAnnotationsCompanion(strokesJson: Value(json)));
      }
    });
  }
}
