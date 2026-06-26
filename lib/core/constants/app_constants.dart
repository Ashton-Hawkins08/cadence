class AppConstants {
  AppConstants._();

  static const int minBpm = 1;
  static const int maxBpm = 300;
  static const int maxHistory = 50;
  static const int maxName = 40;
  static const int maxNote = 300;
  static const int bpmSpikeThreshold = 40;
  static const int defaultReminderDays = 3;
  static const int maxReminderDays = 365;
  static const int maxMinutes = 300;
  static const int minMinutes = 1;

  static const String appName = 'Cadence';
  static const String appTagline = 'Complete Musician Hub';
  static const String appVersion = '2.0.0';

  // SharedPreferences keys
  static const String keyInstrument = 'instrument';
  static const String keyDefaultReminderDays = 'default_reminder_days';
  static const String keyTotalSessions = 'total_sessions';
  static const String keyTotalMinutes = 'total_minutes';
  static const String keyGoalsBeaten = 'goals_beaten';
  static const String keyStreakCurrent = 'streak_current';
  static const String keyStreakLongest = 'streak_longest';
  static const String keyStreakDebt = 'streak_debt';
  static const String keyStreakLastLogDate = 'streak_last_log_date';
  static const String keyStreakLogsToday = 'streak_logs_today';
  static const String keyLastKnownDate = 'last_known_date';
  static const String keyFirstName = 'first_name';
  static const String keyLastName = 'last_name';
  static const String keyOnboardingComplete = 'onboarding_complete';
  static const String keyThemeMode = 'theme_mode';
}
