import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/data/database/app_database.dart';
import 'package:cadence/domain/validators/name_validator.dart';
import 'package:cadence/presentation/providers/categories_provider.dart';
import 'package:cadence/presentation/providers/database_provider.dart';
import 'package:cadence/presentation/providers/exercises_provider.dart';
import 'package:cadence/presentation/screens/exercises/edit_exercise_screen.dart';
import 'package:cadence/presentation/screens/exercises/add_exercise_screen.dart';
import 'package:cadence/presentation/screens/categories/category_notes_screen.dart';

class CategoryExercisesScreen extends ConsumerWidget {
  const CategoryExercisesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final exercisesAsync = ref.watch(exercisesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Category & Exercises'),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'Add Category',
            onPressed: () => _addCategory(context, ref),
          ),
        ],
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (categories) {
          final exercises = exercisesAsync.valueOrNull ?? [];
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // ── Uncategorized (always first, undeletable) ─────────────────
              _CategoryTile(
                categoryId: null,
                categoryName: 'Uncategorized',
                isUncategorized: true,
                exercises: exercises
                    .where((e) => e.categoryId == null)
                    .toList(),
                allCategories: categories,
              ),

              const SizedBox(height: 8),

              // ── Real categories ───────────────────────────────────────────
              ...categories.map((cat) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _CategoryTile(
                      categoryId: cat.id,
                      categoryName: cat.name,
                      isUncategorized: false,
                      exercises: exercises
                          .where((e) => e.categoryId == cat.id)
                          .toList(),
                      allCategories: categories,
                    ),
                  )),

              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addCategory(BuildContext context, WidgetRef ref) async {
    final existing = (ref.read(categoriesProvider).valueOrNull ?? [])
        .map((c) => c.name)
        .toList();
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? savedName;

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, _, __) => AlertDialog(
        title: const Text('New Category'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Category name'),
            validator: (v) {
              final err = NameValidator.validate(v);
              if (err != null) return err;
              if (NameValidator.existsIn(v!.trim(), existing)) {
                return 'A category with this name already exists.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              savedName = NameValidator.sanitize(ctrl.text);
              Navigator.pop(dialogContext);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    ctrl.dispose();

    if (savedName != null && context.mounted) {
      await ref.read(categoryRepositoryProvider).create(savedName!);
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Category tile with expandable exercises
// ──────────────────────────────────────────────────────────────────────────────
class _CategoryTile extends ConsumerWidget {
  final int? categoryId;
  final String categoryName;
  final bool isUncategorized;
  final List<Exercise> exercises;
  final List<Category> allCategories;

  const _CategoryTile({
    required this.categoryId,
    required this.categoryName,
    required this.isUncategorized,
    required this.exercises,
    required this.allCategories,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
          isUncategorized
              ? Icons.inbox_outlined
              : Icons.folder_outlined,
          color: theme.colorScheme.primary,
        ),
        title: Text(
          categoryName,
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isUncategorized)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (v) =>
                    _handleCategoryMenu(context, ref, v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'notes', child: Text('Notes')),
                  PopupMenuItem(
                    value: 'archive',
                    child: Text('Archive',
                        style: TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            const Icon(Icons.expand_more, size: 20),
          ],
        ),
        children: [
          // Exercise list
          ...exercises.map((ex) => _ExerciseTile(
                exercise: ex,
                allCategories: allCategories,
              )),

          // Add exercise button
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Exercise'),
              onPressed: () => _addExercise(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addExercise(BuildContext context, WidgetRef ref) async {
    final categories = allCategories;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddExerciseScreen(
          categories: categories,
          initialCategoryId: categoryId,
        ),
      ),
    );
  }

  Future<void> _handleCategoryMenu(
      BuildContext context, WidgetRef ref, String action) async {
    if (action == 'rename') {
      await _renameCategory(context, ref);
    } else if (action == 'notes') {
      final cat = allCategories.where((c) => c.id == categoryId).firstOrNull;
      if (cat != null && context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CategoryNotesScreen(category: cat),
          ),
        );
      }
    } else if (action == 'archive') {
      await _archiveCategory(context, ref);
    }
  }

  Future<void> _renameCategory(
      BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(text: categoryName);
    final formKey = GlobalKey<FormState>();
    final existing = allCategories.map((c) => c.name).toList();
    String? savedName;

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, _, __) => AlertDialog(
        title: const Text('Rename Category'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(hintText: categoryName),
            validator: (v) {
              final err = NameValidator.validate(v);
              if (err != null) return err;
              if (NameValidator.isSameNormalized(v!.trim(), categoryName)) {
                return null;
              }
              if (NameValidator.existsIn(v.trim(), existing)) {
                return 'A category with this name already exists.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              if (!NameValidator.isSameNormalized(
                  ctrl.text.trim(), categoryName)) {
                savedName = NameValidator.sanitize(ctrl.text);
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    ctrl.dispose();

    if (savedName != null && context.mounted) {
      await ref
          .read(categoryRepositoryProvider)
          .rename(categoryId!, savedName!);
    }
  }

  Future<void> _archiveCategory(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Archive Category?'),
        content: Text(
          'All ${exercises.length} exercise(s) in "$categoryName" will be '
          'archived as a bundle. You can restore them from Archive.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(categoryRepositoryProvider)
          .deleteWithBundle(categoryId!, categoryName);
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Exercise tile (nested, slightly smaller)
// ──────────────────────────────────────────────────────────────────────────────
class _ExerciseTile extends ConsumerWidget {
  final Exercise exercise;
  final List<Category> allCategories;

  const _ExerciseTile({
    required this.exercise,
    required this.allCategories,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
        ),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(Icons.music_note_outlined,
            size: 20, color: theme.colorScheme.primary),
        title: Text(
          exercise.name,
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: exercise.lastBpm > 0
            ? Text(
                'Last: ${exercise.lastBpm} BPM  ·  ${exercise.timesPracticed} session(s)',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              )
            : Text(
                'Never practiced',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 18),
          onSelected: (v) => _handleMenu(context, ref, v),
          itemBuilder: (_) => const [
            PopupMenuItem(
                value: 'edit', child: Text('Edit')),
            PopupMenuItem(
                value: 'notes', child: Text('Notes')),
            PopupMenuItem(
                value: 'switch', child: Text('Switch Category')),
            PopupMenuItem(
                value: 'rename', child: Text('Change Name')),
            PopupMenuItem(
              value: 'archive',
              child: Text('Archive',
                  style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleMenu(
      BuildContext context, WidgetRef ref, String action) async {
    switch (action) {
      case 'edit':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditExerciseScreen(
              exercise: exercise,
              categories: allCategories,
            ),
          ),
        );
      case 'notes':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditExerciseScreen(
              exercise: exercise,
              categories: allCategories,
              initialTabIndex: 1,
            ),
          ),
        );
      case 'switch':
        await _switchCategory(context, ref);
      case 'rename':
        await _renameExercise(context, ref);
      case 'archive':
        await _archiveExercise(context, ref);
    }
  }

  Future<void> _switchCategory(
      BuildContext context, WidgetRef ref) async {
    int? selected = exercise.categoryId;

    final picked = await showDialog<int?>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Switch Category'),
          content: DropdownButtonFormField<int?>(
            value: selected,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Uncategorized'),
              ),
              ...allCategories.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name),
                  )),
            ],
            onChanged: (v) => setState(() => selected = v),
          ),
          actions: [
            TextButton(
                // Return the current categoryId so the diff-check below
                // sees no change and skips the write.
                onPressed: () => Navigator.pop(ctx, exercise.categoryId),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, selected),
              child: const Text('Move'),
            ),
          ],
        ),
      ),
    );

    if (picked != exercise.categoryId) {
      await ref
          .read(exerciseRepositoryProvider)
          .reassignCategory(exercise.id, picked);
    }
  }

  Future<void> _renameExercise(
      BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(text: exercise.name);
    final formKey = GlobalKey<FormState>();
    final repo = ref.read(exerciseRepositoryProvider);
    String? savedName;

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, _, __) => AlertDialog(
        title: const Text('Change Name'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(hintText: exercise.name),
            validator: NameValidator.validate,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final newName = ctrl.text.trim();
              if (!NameValidator.isSameNormalized(newName, exercise.name)) {
                savedName = newName;
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();

    if (savedName != null && context.mounted) {
      final existing = await repo.getByName(savedName!);
      if (existing != null && existing.id != exercise.id) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('An exercise with this name already exists.')),
          );
        }
        return;
      }
      await repo.rename(exercise.id, NameValidator.sanitize(savedName!));
    }
  }

  Future<void> _archiveExercise(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Archive Exercise?'),
        content: Text(
            '"${exercise.name}" will be moved to the archive. You can restore it later.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(exerciseRepositoryProvider)
          .archiveIndividually(exercise.id);
    }
  }
}
