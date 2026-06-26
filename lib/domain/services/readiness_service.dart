import 'progress_service.dart';

class ExerciseReadinessData {
  final int? initialBpm;
  final int? goalBpm;
  final int lastBpm;
  final int highestBpm;
  final DateTime? lastPracticed;
  final int reminderDays;

  const ExerciseReadinessData({
    required this.initialBpm,
    required this.goalBpm,
    required this.lastBpm,
    required this.highestBpm,
    required this.lastPracticed,
    required this.reminderDays,
  });
}

class ReadinessService {
  ReadinessService._();

  // Readiness Score (0–100):
  //   40% — Goal Progress   (avg current progress for exercises with goals; 50 if none set)
  //   35% — Practice Freshness (% of exercises practiced within their reminder threshold)
  //   25% — Streak Health   (streak days / 7, capped at 100%, minus 10% per debt point)
  static double calculate({
    required List<ExerciseReadinessData> exercises,
    required int streakCurrent,
    required int streakDebt,
  }) {
    if (exercises.isEmpty) return 0.0;

    // ── Goal Progress (40%) ───────────────────────────────────────────────────
    final withGoals = exercises
        .where((e) => e.goalBpm != null && e.initialBpm != null)
        .toList();

    double goalScore;
    if (withGoals.isEmpty) {
      goalScore = 50.0; // Neutral when no goals are set
    } else {
      final progresses = withGoals.map((e) {
        return ProgressService.currentProgress(
              initialBpm: e.initialBpm,
              goalBpm: e.goalBpm,
              lastBpm: e.lastBpm,
            ) ??
            0.0;
      }).toList();
      goalScore = progresses.reduce((a, b) => a + b) / progresses.length;
    }

    // ── Practice Freshness (35%) ──────────────────────────────────────────────
    final now = DateTime.now();
    final todayUTC = DateTime.utc(now.year, now.month, now.day);
    final freshCount = exercises.where((e) {
      if (e.lastPracticed == null) return false;
      // Drift returns UTC DateTimes; convert to local before extracting the
      // calendar date so users in non-UTC zones get the right day boundary.
      // Use UTC midnights for subtraction to avoid DST-length days.
      final lpLocal = e.lastPracticed!.toLocal();
      final practicedUTC =
          DateTime.utc(lpLocal.year, lpLocal.month, lpLocal.day);
      return todayUTC.difference(practicedUTC).inDays < e.reminderDays;
    }).length;
    final freshnessScore = (freshCount / exercises.length) * 100.0;

    // ── Streak Health (25%) ───────────────────────────────────────────────────
    final rawStreakScore = ((streakCurrent / 7.0).clamp(0.0, 1.0) * 100.0) -
        (streakDebt * 10.0);
    final streakScore = rawStreakScore.clamp(0.0, 100.0);

    final total = (goalScore * 0.40) +
        (freshnessScore * 0.35) +
        (streakScore * 0.25);

    return total.clamp(0.0, 100.0);
  }

  static String readinessLabel(double score) {
    if (score >= 85) return 'Peak';
    if (score >= 70) return 'Strong';
    if (score >= 50) return 'Building';
    if (score >= 30) return 'Warming Up';
    return 'Getting Started';
  }
}
