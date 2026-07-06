import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/data/database/app_database.dart';
import 'database_provider.dart';

// â”€â”€ Active pieces (not archived) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final allPiecesProvider = StreamProvider<List<MetronomePiece>>((ref) {
  return ref.watch(pieceRepositoryProvider).watchAll();
});

// â”€â”€ Archived pieces â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final archivedPiecesProvider = StreamProvider<List<MetronomePiece>>((ref) {
  return ref.watch(pieceRepositoryProvider).watchArchived();
});

// â”€â”€ Sections for a given piece â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final pieceSectionsProvider =
    StreamProvider.family<List<PieceSection>, int>((ref, pieceId) {
  return ref.watch(pieceRepositoryProvider).watchSectionsForPiece(pieceId);
});
