import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/data/database/app_database.dart';
import 'database_provider.dart';

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchAll();
});

final archivedCategoryBundlesProvider =
    StreamProvider<List<ArchivedCategoryBundle>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchArchived();
});
