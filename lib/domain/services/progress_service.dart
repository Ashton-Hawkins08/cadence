class ProgressResult {
  final double? currentProgress;
  final double? highestProgress;

  const ProgressResult({
    this.currentProgress,
    this.highestProgress,
  });

  bool get hasGoal => currentProgress != null;
  bool get isGoalReached => (currentProgress ?? 0) >= 100.0;

  // Only show both bars when they differ by more than 0.5%
  bool get showBothBars =>
      currentProgress != null &&
      highestProgress != null &&
      (highestProgress! - currentProgress!).abs() > 0.5;
}

class ProgressService {
  ProgressService._();

  static double? currentProgress({
    required int? initialBpm,
    required int? goalBpm,
    required int lastBpm,
  }) {
    if (goalBpm == null || initialBpm == null) return null;
    if (goalBpm <= initialBpm) return null;
    final current = lastBpm > 0 ? lastBpm : initialBpm;
    return ((current - initialBpm) / (goalBpm - initialBpm) * 100)
        .clamp(0.0, 100.0);
  }

  static double? highestProgress({
    required int? initialBpm,
    required int? goalBpm,
    required int highestBpm,
  }) {
    if (goalBpm == null || initialBpm == null) return null;
    if (goalBpm <= initialBpm) return null;
    final peak = highestBpm > 0 ? highestBpm : initialBpm;
    return ((peak - initialBpm) / (goalBpm - initialBpm) * 100)
        .clamp(0.0, 100.0);
  }

  static ProgressResult getProgress({
    required int? initialBpm,
    required int? goalBpm,
    required int lastBpm,
    required int highestBpm,
  }) {
    return ProgressResult(
      currentProgress: currentProgress(
        initialBpm: initialBpm,
        goalBpm: goalBpm,
        lastBpm: lastBpm,
      ),
      highestProgress: highestProgress(
        initialBpm: initialBpm,
        goalBpm: goalBpm,
        highestBpm: highestBpm,
      ),
    );
  }

  // Average current progress across exercises that have goals set.
  // Returns null only if no exercises have goals at all.
  static double? categoryAverageProgress(List<ProgressResult> results) {
    final withGoals = results.where((r) => r.currentProgress != null).toList();
    if (withGoals.isEmpty) return null;
    final sum = withGoals.fold(0.0, (acc, r) => acc + r.currentProgress!);
    return sum / withGoals.length;
  }

  static double? avgBpm(List<int> logs) {
    if (logs.isEmpty) return null;
    return logs.reduce((a, b) => a + b) / logs.length;
  }
}
