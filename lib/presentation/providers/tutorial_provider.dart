import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/presentation/providers/database_provider.dart';

enum TutorialStep {
  welcome,
  navigation,
  createCategory,
  createExercise,
  done,
}

class TutorialNotifier extends Notifier<TutorialStep> {
  @override
  TutorialStep build() => TutorialStep.welcome;

  void advance() {
    state = switch (state) {
      TutorialStep.welcome => TutorialStep.navigation,
      TutorialStep.navigation => TutorialStep.createCategory,
      TutorialStep.createCategory => TutorialStep.createExercise,
      TutorialStep.createExercise => TutorialStep.done,
      TutorialStep.done => TutorialStep.done,
    };
  }

  void skip() {
    state = TutorialStep.done;
  }
}

final tutorialStepProvider =
    NotifierProvider<TutorialNotifier, TutorialStep>(TutorialNotifier.new);

final tutorialCompleteProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.isTutorialComplete();
});
