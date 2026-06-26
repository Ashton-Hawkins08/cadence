import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/data/database/app_database.dart';
import 'database_provider.dart';

// Active exercises — live stream from database
final exercisesProvider = StreamProvider<List<Exercise>>((ref) {
  return ref.watch(exerciseRepositoryProvider).watchActive();
});

// All archived exercises — live stream
final archivedExercisesProvider = StreamProvider<List<Exercise>>((ref) {
  return ref.watch(exerciseRepositoryProvider).watchAllArchived();
});

// BPM logs for a specific exercise
final bpmLogsProvider =
    FutureProvider.family<List<BpmLog>, int>((ref, exerciseId) {
  return ref.watch(exerciseRepositoryProvider).getBpmLogs(exerciseId);
});

// Notes for a specific exercise — live stream
final exerciseNotesProvider =
    StreamProvider.family<List<ExerciseNote>, int>((ref, exerciseId) {
  return ref.watch(exerciseRepositoryProvider).watchNotes(exerciseId);
});
