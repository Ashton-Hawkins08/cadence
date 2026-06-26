import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/data/database/app_database.dart';
import 'package:cadence/domain/services/progress_service.dart';
import 'package:cadence/domain/services/readiness_service.dart';
import 'package:cadence/domain/services/streak_service.dart';
import 'exercises_provider.dart';
import 'streak_provider.dart';
import 'database_provider.dart';

class ExerciseStats {
  final Exercise exercise;
  final List<int> bpmLogValues;

  const ExerciseStats({required this.exercise, required this.bpmLogValues});

  double? get avgBpm => ProgressService.avgBpm(bpmLogValues);

  ProgressResult get progress => ProgressService.getProgress(
        initialBpm: exercise.initialBpm,
        goalBpm: exercise.goalBpm,
        lastBpm: exercise.lastBpm,
        highestBpm: exercise.highestBpm,
      );
}

final readinessProvider = Provider<double>((ref) {
  final exercises = ref.watch(exercisesProvider).valueOrNull ?? [];
  final streak = ref.watch(streakProvider).valueOrNull ?? const StreakState();

  final data = exercises
      .map((e) => ExerciseReadinessData(
            initialBpm: e.initialBpm,
            goalBpm: e.goalBpm,
            lastBpm: e.lastBpm,
            highestBpm: e.highestBpm,
            lastPracticed: e.lastPracticed,
            reminderDays: e.reminderDays,
          ))
      .toList();

  return ReadinessService.calculate(
    exercises: data,
    streakCurrent: streak.current,
    streakDebt: streak.debt,
  );
});

final readinessLabelProvider = Provider<String>((ref) {
  return ReadinessService.readinessLabel(ref.watch(readinessProvider));
});

// Overall average BPM across all active exercises (single bulk query)
final overallAvgBpmProvider = FutureProvider<double?>((ref) async {
  final exercises = ref.watch(exercisesProvider).valueOrNull ?? [];
  if (exercises.isEmpty) return null;

  final exRepo = ref.watch(exerciseRepositoryProvider);
  final ids = exercises.map((e) => e.id).toList();
  final logs = await exRepo.getBpmLogsForExercises(ids);
  return ProgressService.avgBpm(logs.map((l) => l.bpm).toList());
});
