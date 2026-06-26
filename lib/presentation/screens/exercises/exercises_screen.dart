import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/data/database/app_database.dart';
import 'package:cadence/domain/services/progress_service.dart';
import 'package:cadence/presentation/providers/exercises_provider.dart';
import 'package:cadence/presentation/providers/categories_provider.dart';
import 'add_exercise_screen.dart';
import 'edit_exercise_screen.dart';

class ExercisesScreen extends ConsumerStatefulWidget {
  const ExercisesScreen({super.key});

  @override
  ConsumerState<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends ConsumerState<ExercisesScreen> {
  String _search = '';

  PageRouteBuilder _slide(Widget page) => PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0), end: Offset.zero)
              .animate(CurvedAnimation(
                  parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 280),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final exercisesAsync = ref.watch(exercisesProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercises'),
        leading: const BackButton(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
            context, _slide(AddExerciseScreen(categories: categories))),
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search exercises...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),

          Expanded(
            child: exercisesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (exercises) {
                final filtered = exercises
                    .where((e) => e.name
                        .toLowerCase()
                        .contains(_search.toLowerCase()))
                    .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fitness_center,
                            size: 64,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary),
                        const SizedBox(height: 16),
                        Text(
                          exercises.isEmpty
                              ? 'No exercises yet.\nTap + to add your first one.'
                              : 'No results for "$_search"',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final ex = filtered[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ExerciseCard(
                        exercise: ex,
                        onEdit: () => Navigator.push(
                          context,
                          _slide(EditExerciseScreen(
                            exercise: ex,
                            categories: categories,
                          )),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends ConsumerWidget {
  final Exercise exercise;
  final VoidCallback onEdit;

  const _ExerciseCard({required this.exercise, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ex = exercise;

    final progress = ProgressService.getProgress(
      initialBpm: ex.initialBpm,
      goalBpm: ex.goalBpm,
      lastBpm: ex.lastBpm,
      highestBpm: ex.highestBpm,
    );

    return Card(
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      ex.name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                ex.timesPracticed == 0
                    ? 'Not yet practiced'
                    : 'Last BPM: ${ex.lastBpm}  ·  ${ex.timesPracticed} session(s)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              if (progress.hasGoal) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (progress.currentProgress ?? 0) / 100,
                    minHeight: 5,
                    backgroundColor: isDark
                        ? AppColors.darkDivider
                        : AppColors.lightDivider,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Goal: ${ex.initialBpm} → ${ex.goalBpm} BPM  ·  ${progress.currentProgress?.toStringAsFixed(0)}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
