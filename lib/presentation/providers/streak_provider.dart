import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/domain/services/streak_service.dart';
import 'database_provider.dart';

class StreakNotifier extends AsyncNotifier<StreakState> {
  @override
  Future<StreakState> build() async {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.loadStreak();
  }

  Future<StreakUpdateResult> logSession(String today) async {
    // If state is loading or error, reload from SharedPreferences rather than
    // silently resetting the user's streak to a blank StreakState.
    final current = state.valueOrNull ??
        await ref.read(settingsRepositoryProvider).loadStreak();
    final result = StreakService.update(current, today);
    final repo = ref.read(settingsRepositoryProvider);
    await repo.saveStreak(result.newState);
    state = AsyncData(result.newState);
    return result;
  }
}

final streakProvider =
    AsyncNotifierProvider<StreakNotifier, StreakState>(StreakNotifier.new);
