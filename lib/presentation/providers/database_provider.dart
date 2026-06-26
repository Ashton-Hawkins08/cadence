import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/data/database/app_database.dart';
import 'package:cadence/data/repositories/calendar_repository.dart';
import 'package:cadence/data/repositories/piece_repository.dart';
import 'package:cadence/data/repositories/category_repository.dart';
import 'package:cadence/data/repositories/exercise_repository.dart';
import 'package:cadence/data/repositories/history_repository.dart';
import 'package:cadence/data/repositories/settings_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(databaseProvider));
});

final exerciseRepositoryProvider = Provider<ExerciseRepository>((ref) {
  return ExerciseRepository(ref.watch(databaseProvider));
});

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepository(ref.watch(databaseProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return CalendarRepository(ref.watch(databaseProvider));
});

final pieceRepositoryProvider = Provider<PieceRepository>((ref) {
  return PieceRepository(ref.watch(databaseProvider));
});
