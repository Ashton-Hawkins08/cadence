import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/data/database/app_database.dart';
import 'package:cadence/domain/services/progress_service.dart';
import 'package:cadence/presentation/providers/categories_provider.dart';
import 'package:cadence/presentation/providers/exercises_provider.dart';
import 'package:cadence/presentation/providers/settings_provider.dart';
import 'package:cadence/presentation/providers/stats_provider.dart';
import 'package:cadence/presentation/providers/streak_provider.dart';
import 'package:intl/intl.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Stats'),
          bottom: TabBar(
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Category & Exercises'),
            ],
            labelColor: theme.colorScheme.primary,
            indicatorColor: theme.colorScheme.primary,
          ),
        ),
        body: const TabBarView(
          children: [
            _OverviewTab(),
            _CategoryExercisesTab(),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Overview tab
// ──────────────────────────────────────────────────────────────────────────────
class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final readiness = ref.watch(readinessProvider);
    final label = ref.watch(readinessLabelProvider);
    final streakAsync = ref.watch(streakProvider);
    final overallBpmAsync = ref.watch(overallAvgBpmProvider);
    final exercises = ref.watch(exercisesProvider).valueOrNull ?? [];
    final settingsData = ref.watch(settingsProvider).valueOrNull;

    final streak = streakAsync.valueOrNull;
    final totalSessions = settingsData?.totalSessions ?? 0;
    final totalMinutes = settingsData?.totalMinutes ?? 0;
    final exercisesWithGoals =
        exercises.where((e) => e.goalBpm != null).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text('Readiness Score',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    )),
                const SizedBox(height: 12),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: readiness / 100,
                        strokeWidth: 10,
                        backgroundColor: isDark
                            ? AppColors.darkDivider
                            : AppColors.lightDivider,
                        color: AppColors.indigoNavy,
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          '${readiness.toStringAsFixed(0)}%',
                          style: theme.textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                            )),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _StatCell(
              icon: Icons.local_fire_department_outlined,
              label: 'Streak',
              value: streak != null ? '${streak.current} day(s)' : '—',
            ),
            _StatCell(
              icon: Icons.speed_outlined,
              label: 'Avg BPM',
              value: overallBpmAsync.when(
                data: (v) => v != null ? v.toStringAsFixed(0) : '—',
                loading: () => '...',
                error: (_, __) => '—',
              ),
            ),
            _StatCell(
              icon: Icons.playlist_add_check_outlined,
              label: 'Total Sessions',
              value: totalSessions.toString(),
            ),
            _StatCell(
              icon: Icons.timer_outlined,
              label: 'Total Minutes',
              value: totalMinutes.toString(),
            ),
            _StatCell(
              icon: Icons.fitness_center,
              label: 'Exercises',
              value: exercises.length.toString(),
            ),
            _StatCell(
              icon: Icons.flag_outlined,
              label: 'With Goals',
              value: exercisesWithGoals.toString(),
            ),
          ],
        ),

        if (streak != null && streak.debt > 0) ...[
          const SizedBox(height: 16),
          Card(
            color: AppColors.warning.withValues(alpha: 0.12),
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(
                    color: AppColors.warning, width: 1)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_outlined,
                      color: AppColors.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Streak debt: ${streak.debt}/2. '
                      'Practice soon to protect your streak.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCell({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            Text(label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                )),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Category & Exercises stats tab
// ──────────────────────────────────────────────────────────────────────────────
class _CategoryExercisesTab extends ConsumerWidget {
  const _CategoryExercisesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final categoriesAsync = ref.watch(categoriesProvider);
    final exercises = ref.watch(exercisesProvider).valueOrNull ?? [];

    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (categories) {
        final uncategorized =
            exercises.where((e) => e.categoryId == null).toList();

        if (categories.isEmpty && uncategorized.isEmpty) {
          return Center(
            child: Text(
              'No exercises yet.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (uncategorized.isNotEmpty)
              _StatsCategoryTile(
                categoryName: 'Uncategorized',
                exercises: uncategorized,
                isUncategorized: true,
              ),
            if (uncategorized.isNotEmpty && categories.isNotEmpty)
              const SizedBox(height: 8),
            ...categories.map((cat) {
              final catExercises =
                  exercises.where((e) => e.categoryId == cat.id).toList();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _StatsCategoryTile(
                  categoryName: cat.name,
                  exercises: catExercises,
                  isUncategorized: false,
                ),
              );
            }),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

class _StatsCategoryTile extends StatelessWidget {
  final String categoryName;
  final List<Exercise> exercises;
  final bool isUncategorized;

  const _StatsCategoryTile({
    required this.categoryName,
    required this.exercises,
    this.isUncategorized = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final withBpm = exercises.where((e) => e.lastBpm > 0).toList();
    final avgBpm = withBpm.isEmpty
        ? null
        : withBpm.map((e) => e.lastBpm).reduce((a, b) => a + b) /
            withBpm.length;
    final totalSessions =
        exercises.fold<int>(0, (s, e) => s + e.timesPracticed);

    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        collapsedBackgroundColor:
            isDark ? AppColors.darkCard : AppColors.lightCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        leading: Icon(
            isUncategorized ? Icons.inbox_outlined : Icons.folder_outlined,
            color: theme.colorScheme.primary),
        title: Text(
          categoryName,
          style: theme.textTheme.bodyLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Wrap(
          spacing: 8,
          children: [
            _MiniChip('${exercises.length} exercise(s)'),
            if (avgBpm != null)
              _MiniChip('Avg ${avgBpm.toStringAsFixed(0)} BPM'),
            if (totalSessions > 0) _MiniChip('$totalSessions session(s)'),
          ],
        ),
        children: exercises.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No exercises in this category.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
              ]
            : exercises
                .map((ex) => _StatsExerciseTile(exercise: ex))
                .toList(),
      ),
    );
  }
}

class _StatsExerciseTile extends StatelessWidget {
  final Exercise exercise;
  const _StatsExerciseTile({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ex = exercise;

    final progress = ProgressService.getProgress(
      initialBpm: ex.initialBpm,
      goalBpm: ex.goalBpm,
      lastBpm: ex.lastBpm,
      highestBpm: ex.highestBpm,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(ex.name,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                Text(
                  '${ex.timesPracticed} session(s)',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (ex.lastBpm > 0) _MiniChip('Last: ${ex.lastBpm} BPM'),
                if (ex.highestBpm > 0)
                  _MiniChip('Best: ${ex.highestBpm} BPM'),
                _MiniChip('${ex.totalMinutes} min'),
                if (ex.lastPracticed != null)
                  _MiniChip(DateFormat('MMM d').format(ex.lastPracticed!.toLocal())),
              ],
            ),
            if (progress.hasGoal) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (progress.currentProgress ?? 0) / 100,
                  minHeight: 4,
                  backgroundColor: isDark
                      ? AppColors.darkDivider
                      : AppColors.lightDivider,
                  color: AppColors.indigoNavy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${ex.initialBpm} → ${ex.goalBpm} BPM  ·  '
                '${progress.currentProgress?.toStringAsFixed(0)}% complete',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  const _MiniChip(this.label);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
        ),
      ),
      child: Text(label, style: theme.textTheme.labelSmall),
    );
  }
}
