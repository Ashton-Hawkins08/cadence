import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/data/repositories/settings_repository.dart';
import 'calendar_provider.dart';
import 'database_provider.dart';
import 'exercises_provider.dart';
import 'categories_provider.dart';
import 'streak_provider.dart';
import 'history_provider.dart';
import 'piece_provider.dart';

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.load();
  }

  Future<void> setFirstName(String name) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.saveFirstName(name);
    state = state.whenData((s) => s.copyWith(firstName: name));
  }

  Future<void> setLastName(String name) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.saveLastName(name);
    state = state.whenData((s) => s.copyWith(lastName: name));
  }

  Future<void> setInstrument(String instrument) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.saveInstrument(instrument);
    state = state.whenData((s) => s.copyWith(instrument: instrument));
  }

  Future<void> setDefaultReminderDays(int days) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.saveDefaultReminderDays(days);
    state = state.whenData((s) => s.copyWith(defaultReminderDays: days));
  }

  Future<void> setTheme(ThemePreference theme) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.saveTheme(theme);
    state = state.whenData((s) => s.copyWith(themePreference: theme));
  }

  Future<void> recordSession(int minutes) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.incrementSession(minutes);
    state = state.whenData((s) => s.copyWith(
          totalSessions: s.totalSessions + 1,
          totalMinutes: s.totalMinutes + minutes,
        ));
  }

  Future<void> recordGoalBeaten() async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.incrementGoalsBeaten();
    state = state.whenData((s) => s.copyWith(goalsBeaten: s.goalsBeaten + 1));
  }

  Future<void> resetAllData() async {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final exerciseRepo = ref.read(exerciseRepositoryProvider);
    final categoryRepo = ref.read(categoryRepositoryProvider);
    final historyRepo = ref.read(historyRepositoryProvider);
    final calendarRepo = ref.read(calendarRepositoryProvider);

    await exerciseRepo.deleteAllBpmLogs();
    await exerciseRepo.deleteAllNotes();
    await exerciseRepo.deleteAll();
    await categoryRepo.deleteAllCategoryNotes();
    await categoryRepo.deleteAll();
    await categoryRepo.deleteAllBundles();
    await historyRepo.deleteAll();
    await calendarRepo.deleteAll();
    final pieceRepo = ref.read(pieceRepositoryProvider);
    await pieceRepo.deleteAll();
    await settingsRepo.clearStats();

    ref.invalidate(exercisesProvider);
    ref.invalidate(categoriesProvider);
    ref.invalidate(streakProvider);
    ref.invalidate(historyProvider);

    state = state.whenData((s) => s.copyWith(
          totalSessions: 0,
          totalMinutes: 0,
          goalsBeaten: 0,
        ));
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

// Convenience — resolves ThemeMode for MaterialApp
final themeModeProvider = Provider<ThemeMode>((ref) {
  final settings = ref.watch(settingsProvider).valueOrNull;
  return switch (settings?.themePreference) {
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
    _ => ThemeMode.system,
  };
});
