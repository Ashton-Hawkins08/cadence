import 'package:shared_preferences/shared_preferences.dart';
import 'package:cadence/core/constants/app_constants.dart';
import 'package:cadence/domain/services/streak_service.dart';

class AppSettings {
  final String firstName;
  final String lastName;
  final String instrument;
  final int defaultReminderDays;
  final int totalSessions;
  final int totalMinutes;
  final int goalsBeaten;
  final ThemePreference themePreference;

  const AppSettings({
    required this.firstName,
    required this.lastName,
    required this.instrument,
    required this.defaultReminderDays,
    required this.totalSessions,
    required this.totalMinutes,
    required this.goalsBeaten,
    required this.themePreference,
  });

  AppSettings copyWith({
    String? firstName,
    String? lastName,
    String? instrument,
    int? defaultReminderDays,
    int? totalSessions,
    int? totalMinutes,
    int? goalsBeaten,
    ThemePreference? themePreference,
  }) =>
      AppSettings(
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        instrument: instrument ?? this.instrument,
        defaultReminderDays: defaultReminderDays ?? this.defaultReminderDays,
        totalSessions: totalSessions ?? this.totalSessions,
        totalMinutes: totalMinutes ?? this.totalMinutes,
        goalsBeaten: goalsBeaten ?? this.goalsBeaten,
        themePreference: themePreference ?? this.themePreference,
      );

  int get totalHours => totalMinutes ~/ 60;
  int get remainingMinutes => totalMinutes % 60;

  String get displayName =>
      firstName.isNotEmpty ? firstName : (instrument.isNotEmpty ? instrument : 'Musician');
}

enum ThemePreference { light, dark, system }

class SettingsRepository {
  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString(AppConstants.keyThemeMode) ?? 'system';
    return AppSettings(
      firstName: prefs.getString(AppConstants.keyFirstName) ?? '',
      lastName: prefs.getString(AppConstants.keyLastName) ?? '',
      instrument: prefs.getString(AppConstants.keyInstrument) ?? '',
      defaultReminderDays: prefs.getInt(AppConstants.keyDefaultReminderDays) ??
          AppConstants.defaultReminderDays,
      totalSessions: prefs.getInt(AppConstants.keyTotalSessions) ?? 0,
      totalMinutes: prefs.getInt(AppConstants.keyTotalMinutes) ?? 0,
      goalsBeaten: prefs.getInt(AppConstants.keyGoalsBeaten) ?? 0,
      themePreference: ThemePreference.values.firstWhere(
        (t) => t.name == themeStr,
        orElse: () => ThemePreference.system,
      ),
    );
  }

  Future<void> saveFirstName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyFirstName, name);
  }

  Future<void> saveLastName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyLastName, name);
  }

  Future<void> saveInstrument(String instrument) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyInstrument, instrument);
  }

  Future<void> saveDefaultReminderDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.keyDefaultReminderDays, days);
  }

  Future<void> saveTheme(ThemePreference theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyThemeMode, theme.name);
  }

  Future<void> incrementSession(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = (prefs.getInt(AppConstants.keyTotalSessions) ?? 0) + 1;
    final totalMin = (prefs.getInt(AppConstants.keyTotalMinutes) ?? 0) + minutes;
    await prefs.setInt(AppConstants.keyTotalSessions, sessions);
    await prefs.setInt(AppConstants.keyTotalMinutes, totalMin);
  }

  Future<void> incrementGoalsBeaten() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(AppConstants.keyGoalsBeaten) ?? 0;
    await prefs.setInt(AppConstants.keyGoalsBeaten, current + 1);
  }

  Future<void> clearStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.keyTotalSessions, 0);
    await prefs.setInt(AppConstants.keyTotalMinutes, 0);
    await prefs.setInt(AppConstants.keyGoalsBeaten, 0);
    await prefs.setInt(AppConstants.keyStreakCurrent, 0);
    await prefs.setInt(AppConstants.keyStreakLongest, 0);
    await prefs.setInt(AppConstants.keyStreakDebt, 0);
    await prefs.setInt(AppConstants.keyStreakLogsToday, 0);
    await prefs.remove(AppConstants.keyStreakLastLogDate);
  }

  Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.keyOnboardingComplete) ?? false;
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyOnboardingComplete, true);
  }

  // ── Streak ────────────────────────────────────────────────────────────────

  Future<StreakState> loadStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return StreakState(
      current: prefs.getInt(AppConstants.keyStreakCurrent) ?? 0,
      longest: prefs.getInt(AppConstants.keyStreakLongest) ?? 0,
      debt: prefs.getInt(AppConstants.keyStreakDebt) ?? 0,
      lastLogDate: prefs.getString(AppConstants.keyStreakLastLogDate),
      logsToday: prefs.getInt(AppConstants.keyStreakLogsToday) ?? 0,
    );
  }

  Future<void> saveStreak(StreakState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.keyStreakCurrent, state.current);
    await prefs.setInt(AppConstants.keyStreakLongest, state.longest);
    await prefs.setInt(AppConstants.keyStreakDebt, state.debt);
    await prefs.setInt(AppConstants.keyStreakLogsToday, state.logsToday);
    if (state.lastLogDate != null) {
      await prefs.setString(AppConstants.keyStreakLastLogDate, state.lastLogDate!);
    }
  }
}
