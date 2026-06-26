import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/data/database/app_database.dart';
import 'database_provider.dart';

final historyProvider = StreamProvider<List<HistoryEntry>>((ref) {
  return ref.watch(historyRepositoryProvider).watchRecent();
});
