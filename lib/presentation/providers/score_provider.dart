import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/data/database/app_database.dart';
import 'package:cadence/data/repositories/score_repository.dart';
import 'database_provider.dart';

final scoreRepositoryProvider = Provider<ScoreRepository>((ref) {
  return ScoreRepository(ref.watch(databaseProvider));
});

final scoreFoldersProvider = StreamProvider<List<ScoreFolder>>((ref) {
  return ref.watch(scoreRepositoryProvider).watchFolders();
});

final scorePagesProvider =
    StreamProvider.family<List<ScorePage>, int>((ref, folderId) {
  return ref.watch(scoreRepositoryProvider).watchPages(folderId);
});

final scoreTurnsProvider =
    StreamProvider.family<List<ScorePageTurn>, int>((ref, folderId) {
  return ref.watch(scoreRepositoryProvider).watchTurns(folderId);
});
