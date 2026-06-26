import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/constants/app_constants.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/data/database/app_database.dart';
import 'package:cadence/domain/services/date_service.dart';
import 'package:cadence/domain/services/progress_service.dart';
import 'package:cadence/domain/services/streak_service.dart';
import 'package:cadence/presentation/providers/categories_provider.dart';
import 'package:cadence/presentation/providers/exercises_provider.dart';
import 'package:cadence/presentation/providers/streak_provider.dart';
import 'package:cadence/presentation/providers/settings_provider.dart';
import 'package:cadence/presentation/providers/database_provider.dart';
import 'package:cadence/presentation/providers/nav_provider.dart';
import 'package:drift/drift.dart' show Value;

class LogSessionScreen extends ConsumerStatefulWidget {
  const LogSessionScreen({super.key});

  @override
  ConsumerState<LogSessionScreen> createState() => _LogSessionScreenState();
}

class _LogSessionScreenState extends ConsumerState<LogSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _minutesController = TextEditingController();
  final _bpmController = TextEditingController();
  final _noteController = TextEditingController();

  Exercise? _selectedExercise;
  bool _saving = false;

  @override
  void dispose() {
    _minutesController.dispose();
    _bpmController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _showExercisePicker(
      List<Exercise> exercises, List<Category> categories) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExercisePickerSheet(
        categories: categories,
        exercises: exercises,
        selected: _selectedExercise,
        onSelected: (ex) {
          setState(() => _selectedExercise = ex);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _submit() async {
    if (_selectedExercise == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an exercise.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final minutes = int.parse(_minutesController.text);
    final bpm = int.parse(_bpmController.text);
    final ex = _selectedExercise!;

    // BPM spike check
    if (ex.lastBpm > 0) {
      final delta = (bpm - ex.lastBpm).abs();
      if (delta >= AppConstants.bpmSpikeThreshold) {
        final confirmed = await _showSpikeWarning(ex.lastBpm, bpm, delta);
        if (!mounted) return;
        if (!confirmed) return;
      }
    }

    setState(() => _saving = true);
    try {
      final today = await DateService.getSafeToday();
      final exRepo = ref.read(exerciseRepositoryProvider);
      final histRepo = ref.read(historyRepositoryProvider);
      final note = _noteController.text.trim();

      // Update exercise stats
      final newHighest = bpm > ex.highestBpm ? bpm : ex.highestBpm;
      await exRepo.update(
        ex.id,
        ExercisesCompanion(
          timesPracticed: Value(ex.timesPracticed + 1),
          totalMinutes: Value(ex.totalMinutes + minutes),
          lastBpm: Value(bpm),
          highestBpm: Value(newHighest),
          lastPracticed: Value(DateTime.now()),
        ),
      );

      // Record BPM log
      await exRepo.addBpmLog(ex.id, bpm);

      // Attach note to exercise if provided
      if (note.isNotEmpty) {
        await exRepo.addNote(ex.id, note);
      }

      // Add to history
      await histRepo.addEntry(
        exerciseId: ex.id,
        exerciseName: ex.name,
        minutes: minutes,
        bpm: bpm,
        note: note,
      );

      // Update global stats
      await ref.read(settingsProvider.notifier).recordSession(minutes);

      // Update streak
      final streakResult =
          await ref.read(streakProvider.notifier).logSession(today);

      // Fetch updated BPM logs for progress calculation
      final bpmLogs = await exRepo.getBpmLogs(ex.id);
      final bpmValues = bpmLogs.map((l) => l.bpm).toList();
      final progress = ProgressService.getProgress(
        initialBpm: ex.initialBpm,
        goalBpm: ex.goalBpm,
        lastBpm: bpm,
        highestBpm: newHighest,
      );

      // Only count goal-beaten and show dialog on FIRST reach, not on every
      // subsequent session logged above the goal.
      final wasGoalAlreadyReached = ex.goalBpm != null && ex.lastBpm >= ex.goalBpm!;
      final goalJustReached = !wasGoalAlreadyReached && progress.isGoalReached;

      if (goalJustReached) {
        await ref.read(settingsProvider.notifier).recordGoalBeaten();
      }

      if (!mounted) return;
      await _showResult(
        ex: ex,
        minutes: minutes,
        bpm: bpm,
        newHighest: newHighest,
        avgBpm: ProgressService.avgBpm(bpmValues),
        progress: progress,
        streakResult: streakResult,
        goalReached: goalJustReached,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _showSpikeWarning(int lastBpm, int newBpm, int delta) async {
    final direction = newBpm > lastBpm ? '+$delta' : '-$delta';
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('BPM Spike Warning'),
            content: Text(
              'Your last log was $lastBpm BPM.\n'
              'You entered $newBpm BPM — that\'s a $direction BPM change.\n\n'
              'If this is a mistake it will skew your average. Log anyway?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Go Back'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Log Anyway'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _showResult({
    required Exercise ex,
    required int minutes,
    required int bpm,
    required int newHighest,
    required double? avgBpm,
    required ProgressResult progress,
    required StreakUpdateResult streakResult,
    required bool goalReached,
  }) async {
    final streak = ref.read(streakProvider).valueOrNull;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SessionResultDialog(
        exerciseName: ex.name,
        minutes: minutes,
        bpm: bpm,
        highestBpm: newHighest,
        avgBpm: avgBpm,
        progress: progress,
        streakCurrent: streak?.current ?? 1,
        streakDebt: streak?.debt ?? 0,
        isNewRecord: streakResult.isNewRecord,
        goalReached: goalReached,
        onDone: () => Navigator.pop(context),
      ),
    );

    if (!mounted) return;

    setState(() {
      _selectedExercise = null;
      _minutesController.clear();
      _bpmController.clear();
      _noteController.clear();
    });

    if (goalReached) {
      await showDialog(
        context: context,
        builder: (_) => _GoalCompleteDialog(exercise: ex),
      );
      if (!mounted) return;
    }

    ref.read(navIndexProvider.notifier).state = 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final exercises = ref.watch(exercisesProvider).valueOrNull ?? [];
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Log Session')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Exercise selector
            Text('Exercise', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: exercises.isEmpty
                  ? null
                  : () => _showExercisePicker(exercises, categories),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedExercise != null
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.fitness_center_outlined,
                        color: theme.colorScheme.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        exercises.isEmpty
                            ? 'No exercises yet — add some first'
                            : (_selectedExercise?.name ??
                                'Tap to select exercise'),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: _selectedExercise != null
                              ? null
                              : (isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary),
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Minutes
            Text('Minutes Practiced', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            TextFormField(
              controller: _minutesController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: '1 – 300',
                prefixIcon: Icon(Icons.timer_outlined),
              ),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null) return 'Enter a number.';
                if (n < AppConstants.minMinutes || n > AppConstants.maxMinutes) {
                  return 'Must be ${AppConstants.minMinutes}–${AppConstants.maxMinutes} minutes.';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // BPM
            Text('BPM', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            TextFormField(
              controller: _bpmController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: '1 – 300',
                prefixIcon: Icon(Icons.speed_outlined),
              ),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null) return 'Enter a number.';
                if (n < AppConstants.minBpm || n > AppConstants.maxBpm) {
                  return 'Must be ${AppConstants.minBpm}–${AppConstants.maxBpm} BPM.';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // Note (optional)
            Text('Session Note (optional)', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteController,
              maxLines: 3,
              maxLength: AppConstants.maxNote,
              decoration: const InputDecoration(
                hintText: 'How did it go? (optional)',
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: Icon(Icons.edit_note_outlined),
                ),
                counterText: '',
              ),
              validator: (v) {
                if ((v?.length ?? 0) > AppConstants.maxNote) {
                  return 'Max ${AppConstants.maxNote} characters.';
                }
                return null;
              },
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_saving || exercises.isEmpty) ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Log Session'),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Exercise Picker Sheet ─────────────────────────────────────────────────────

class _ExercisePickerSheet extends StatefulWidget {
  final List<Category> categories;
  final List<Exercise> exercises;
  final Exercise? selected;
  final ValueChanged<Exercise> onSelected;

  const _ExercisePickerSheet({
    required this.categories,
    required this.exercises,
    required this.selected,
    required this.onSelected,
  });

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 60, 0, 0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search exercises...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: _search.isNotEmpty
                ? _buildFlatList(theme, isDark)
                : _buildCategoryList(theme, isDark, cardColor),
          ),
        ],
      ),
    );
  }

  Widget _buildFlatList(ThemeData theme, bool isDark) {
    final filtered = widget.exercises
        .where((e) => e.name.toLowerCase().contains(_search.toLowerCase()))
        .toList();
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final ex = filtered[i];
        final isSelected = widget.selected?.id == ex.id;
        return ListTile(
          title: Text(ex.name),
          subtitle: Text(
            ex.lastBpm > 0 ? 'Last BPM: ${ex.lastBpm}' : 'Not yet practiced',
          ),
          trailing: isSelected
              ? Icon(Icons.check, color: theme.colorScheme.primary)
              : null,
          selected: isSelected,
          onTap: () => widget.onSelected(ex),
        );
      },
    );
  }

  Widget _buildCategoryList(
      ThemeData theme, bool isDark, Color cardColor) {
    final uncategorized =
        widget.exercises.where((e) => e.categoryId == null).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      children: [
        if (uncategorized.isNotEmpty)
          _buildCategoryTile(
            theme: theme,
            isDark: isDark,
            cardColor: cardColor,
            icon: Icons.inbox_outlined,
            title: 'Uncategorized',
            exercises: uncategorized,
          ),
        ...widget.categories.map((cat) {
          final catExercises =
              widget.exercises.where((e) => e.categoryId == cat.id).toList();
          if (catExercises.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _buildCategoryTile(
              theme: theme,
              isDark: isDark,
              cardColor: cardColor,
              icon: Icons.folder_outlined,
              title: cat.name,
              exercises: catExercises,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCategoryTile({
    required ThemeData theme,
    required bool isDark,
    required Color cardColor,
    required IconData icon,
    required String title,
    required List<Exercise> exercises,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        backgroundColor: cardColor,
        collapsedBackgroundColor: cardColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(
          title,
          style: theme.textTheme.bodyLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${exercises.length} exercise${exercises.length == 1 ? '' : 's'}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
        children: exercises.map((ex) {
          final isSelected = widget.selected?.id == ex.id;
          return Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : (isDark
                        ? AppColors.darkDivider
                        : AppColors.lightDivider),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: ListTile(
              dense: true,
              leading: Icon(Icons.music_note_outlined,
                  size: 20, color: theme.colorScheme.primary),
              title: Text(
                ex.name,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                ex.lastBpm > 0
                    ? 'Last BPM: ${ex.lastBpm}'
                    : 'Not yet practiced',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              trailing: isSelected
                  ? Icon(Icons.check, color: theme.colorScheme.primary)
                  : null,
              onTap: () => widget.onSelected(ex),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Session Result Dialog ─────────────────────────────────────────────────────

class _SessionResultDialog extends StatelessWidget {
  final String exerciseName;
  final int minutes;
  final int bpm;
  final int highestBpm;
  final double? avgBpm;
  final ProgressResult progress;
  final int streakCurrent;
  final int streakDebt;
  final bool isNewRecord;
  final bool goalReached;
  final VoidCallback onDone;

  const _SessionResultDialog({
    required this.exerciseName,
    required this.minutes,
    required this.bpm,
    required this.highestBpm,
    required this.avgBpm,
    required this.progress,
    required this.streakCurrent,
    required this.streakDebt,
    required this.isNewRecord,
    required this.goalReached,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.success, size: 24),
          const SizedBox(width: 8),
          const Text('Session Logged!'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(exerciseName,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _Row('Time', '$minutes min'),
            _Row('BPM', '$bpm'),
            _Row('Highest', '$highestBpm BPM'),
            if (avgBpm != null) _Row('Avg BPM', avgBpm!.toStringAsFixed(0)),
            if (progress.hasGoal) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: (progress.currentProgress ?? 0) / 100,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 4),
              Text(
                'Goal Progress: ${progress.currentProgress?.toStringAsFixed(0)}%',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const Divider(height: 24),
            Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  '$streakCurrent day streak',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (isNewRecord) ...[
              const SizedBox(height: 4),
              Text('🏆 New record!',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.success, fontWeight: FontWeight.w600)),
            ],
            if (streakDebt > 0) ...[
              const SizedBox(height: 4),
              Text('⚠️ Streak debt: $streakDebt day(s)',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.streakDebt)),
            ],
            if (goalReached) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Text('🎉', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Goal reached!',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: onDone,
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          Text(value,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Goal Complete Dialog ──────────────────────────────────────────────────────

class _GoalCompleteDialog extends ConsumerStatefulWidget {
  final Exercise exercise;
  const _GoalCompleteDialog({required this.exercise});

  @override
  ConsumerState<_GoalCompleteDialog> createState() =>
      _GoalCompleteDialogState();
}

class _GoalCompleteDialogState extends ConsumerState<_GoalCompleteDialog> {
  int _choice = 3; // 1=new goal, 2=remove, 3=keep (default: keep)
  final _newInitialCtrl = TextEditingController();
  final _newGoalCtrl = TextEditingController();

  @override
  void dispose() {
    _newInitialCtrl.dispose();
    _newGoalCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final repo = ref.read(exerciseRepositoryProvider);
    if (_choice == 1) {
      final initial = int.tryParse(_newInitialCtrl.text);
      final goal = int.tryParse(_newGoalCtrl.text);
      if (initial == null ||
          goal == null ||
          initial < AppConstants.minBpm ||
          initial > AppConstants.maxBpm ||
          goal < AppConstants.minBpm ||
          goal > AppConstants.maxBpm ||
          goal <= initial) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Enter valid BPM values with goal above starting BPM.')),
          );
        }
        return;
      }
      await repo.update(
        widget.exercise.id,
        ExercisesCompanion(
          initialBpm: Value(initial),
          goalBpm: Value(goal),
        ),
      );
    } else if (_choice == 2) {
      await repo.update(
        widget.exercise.id,
        const ExercisesCompanion(
          initialBpm: Value(null),
          goalBpm: Value(null),
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('🎉 Goal Reached!'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('You hit your target BPM for "${widget.exercise.name}"!'),
          const SizedBox(height: 16),
          RadioListTile<int>(
            value: 3,
            groupValue: _choice,
            title: const Text('Keep it as-is'),
            onChanged: (v) => setState(() => _choice = v!),
            contentPadding: EdgeInsets.zero,
          ),
          RadioListTile<int>(
            value: 1,
            groupValue: _choice,
            title: const Text('Set a new, harder goal'),
            onChanged: (v) => setState(() => _choice = v!),
            contentPadding: EdgeInsets.zero,
          ),
          if (_choice == 1) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _newInitialCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'New starting BPM',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _newGoalCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'New goal BPM',
                isDense: true,
              ),
            ),
          ],
          RadioListTile<int>(
            value: 2,
            groupValue: _choice,
            title: const Text('Remove goal for now'),
            onChanged: (v) => setState(() => _choice = v!),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
