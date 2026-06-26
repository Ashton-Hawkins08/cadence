import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/data/database/app_database.dart';
import 'package:cadence/data/repositories/piece_repository.dart';
import 'database_provider.dart';

// ── Active pieces (not archived) ──────────────────────────────────────────────

final allPiecesProvider = StreamProvider<List<MetronomePiece>>((ref) {
  return ref.watch(pieceRepositoryProvider).watchAll();
});

// ── Archived pieces ───────────────────────────────────────────────────────────

final archivedPiecesProvider = StreamProvider<List<MetronomePiece>>((ref) {
  return ref.watch(pieceRepositoryProvider).watchArchived();
});

// ── Sections for a given piece ────────────────────────────────────────────────

final pieceSectionsProvider =
    StreamProvider.family<List<PieceSection>, int>((ref, pieceId) {
  return ref.watch(pieceRepositoryProvider).watchSectionsForPiece(pieceId);
});
