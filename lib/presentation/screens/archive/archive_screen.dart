import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/data/database/app_database.dart';
import 'package:cadence/domain/validators/name_validator.dart';
import 'package:cadence/presentation/providers/categories_provider.dart';
import 'package:cadence/presentation/providers/database_provider.dart';
import 'package:cadence/presentation/providers/exercises_provider.dart';
import 'package:cadence/presentation/providers/piece_provider.dart';
import 'package:intl/intl.dart';

// Wraps the chosen categoryId so we can distinguish "Uncategorized" (null)
// from "dialog cancelled" (the outer Future returns null).
class _CategoryResult {
  final int? categoryId;
  const _CategoryResult(this.categoryId);
}

// Shows a dialog asking which category to restore an exercise into.
// Returns null if the user cancels; _CategoryResult otherwise.
Future<_CategoryResult?> _showCategoryPicker(
  BuildContext context,
  List<Category> categories,
  String exerciseName,
) {
  return showDialog<_CategoryResult>(
    context: context,
    builder: (ctx) {
      int? picked; // null = Uncategorized until user taps
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Restore to…'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Where would you like to send "$exerciseName"?',
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      RadioListTile<int?>(
                        value: null,
                        groupValue: picked,
                        title: const Text('Uncategorized'),
                        onChanged: (v) => setState(() => picked = v),
                      ),
                      ...categories.map((c) => RadioListTile<int?>(
                            value: c.id,
                            groupValue: picked,
                            title: Text(c.name),
                            onChanged: (v) => setState(() => picked = v),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(ctx, _CategoryResult(picked)),
              child: const Text('Restore'),
            ),
          ],
        ),
      );
    },
  );
}

class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archivedExercisesAsync = ref.watch(archivedExercisesProvider);
    final bundlesAsync = ref.watch(archivedCategoryBundlesProvider);
    final archivedPiecesAsync = ref.watch(archivedPiecesProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Archive'),
          leading: const BackButton(),
          bottom: TabBar(
            tabs: const [
              Tab(text: 'Exercises'),
              Tab(text: 'Category Bundles'),
              Tab(text: 'Pieces'),
            ],
            labelColor: Theme.of(context).colorScheme.primary,
            indicatorColor: Theme.of(context).colorScheme.primary,
          ),
        ),
        body: TabBarView(
          children: [
            // ── Individual Archived Exercises ─────────────────────────────
            archivedExercisesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (exercises) =>
                  _ExerciseArchiveTab(exercises: exercises),
            ),

            // ── Category Bundles ──────────────────────────────────────────
            bundlesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (bundles) {
                final archivedExercises =
                    archivedExercisesAsync.valueOrNull ?? [];
                return _BundleArchiveTab(
                  bundles: bundles,
                  allArchived: archivedExercises,
                );
              },
            ),

            // ── Archived Pieces ───────────────────────────────────────────
            archivedPiecesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (pieces) => _PieceArchiveTab(pieces: pieces),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Archived pieces tab
// ──────────────────────────────────────────────────────────────────────────────
class _PieceArchiveTab extends ConsumerWidget {
  final List<MetronomePiece> pieces;
  const _PieceArchiveTab({required this.pieces});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (pieces.isEmpty) {
      return Center(
        child: Text('No archived pieces.',
            style: theme.textTheme.bodyMedium),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pieces.length,
      itemBuilder: (_, i) {
        final p = pieces[i];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.timeline_outlined),
            title: Text(p.title),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Restore',
                  icon: const Icon(Icons.unarchive_outlined),
                  onPressed: () =>
                      ref.read(pieceRepositoryProvider).restore(p.id),
                ),
                IconButton(
                  tooltip: 'Delete permanently',
                  icon: Icon(Icons.delete_outline,
                      color: theme.colorScheme.error),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete piece?'),
                        content: Text(
                            '"${p.title}" and its sections will be permanently deleted.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel')),
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await ref.read(pieceRepositoryProvider).delete(p.id);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Individual exercises tab
// ──────────────────────────────────────────────────────────────────────────────
class _ExerciseArchiveTab extends ConsumerWidget {
  final List<Exercise> exercises;
  const _ExerciseArchiveTab({required this.exercises});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final individual =
        exercises.where((e) => e.archivedIndividually).toList();

    if (individual.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.archive_outlined,
                size: 64,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary),
            const SizedBox(height: 16),
            Text(
              'No archived exercises.',
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

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: individual.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final ex = individual[i];
        return Card(
          child: ListTile(
            title: Text(ex.name,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            subtitle: ex.lastBpm > 0
                ? Text(
                    'Last BPM: ${ex.lastBpm}  ·  ${ex.timesPracticed} session(s)')
                : const Text('Never practiced'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.unarchive_outlined,
                      color: theme.colorScheme.primary),
                  tooltip: 'Restore',
                  onPressed: () =>
                      _restoreExercise(context, ref, ex),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.error),
                  tooltip: 'Delete permanently',
                  onPressed: () =>
                      _confirmPermanentDelete(context, ref, ex),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _restoreExercise(
      BuildContext context, WidgetRef ref, Exercise ex) async {
    final categories = ref.read(categoriesProvider).valueOrNull ?? [];
    final result =
        await _showCategoryPicker(context, categories, ex.name);
    if (result == null || !context.mounted) return;

    await ref
        .read(exerciseRepositoryProvider)
        .restoreExercise(ex.id, result.categoryId);

    if (context.mounted) {
      final dest = result.categoryId == null
          ? 'Uncategorized'
          : (categories
                  .where((c) => c.id == result.categoryId)
                  .firstOrNull
                  ?.name ??
              'category');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${ex.name}" restored to $dest.')),
      );
    }
  }

  Future<void> _confirmPermanentDelete(
      BuildContext context, WidgetRef ref, Exercise ex) async {
    final ctrl = TextEditingController();
    bool confirmed = false;

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, _, __) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Permanently Delete?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This cannot be undone. Type "${ex.name}" to confirm.',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                decoration: InputDecoration(hintText: ex.name),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white),
              onPressed: NameValidator.isSameNormalized(ctrl.text, ex.name)
                  ? () {
                      confirmed = true;
                      Navigator.pop(dialogContext);
                    }
                  : null,
              child: const Text('Delete Forever'),
            ),
          ],
        ),
      ),
    );

    ctrl.dispose();

    if (confirmed && context.mounted) {
      await ref
          .read(exerciseRepositoryProvider)
          .permanentlyDelete(ex.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('"${ex.name}" permanently deleted.')),
        );
      }
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Category bundles tab
// ──────────────────────────────────────────────────────────────────────────────
class _BundleArchiveTab extends ConsumerWidget {
  final List<ArchivedCategoryBundle> bundles;
  final List<Exercise> allArchived;

  const _BundleArchiveTab({
    required this.bundles,
    required this.allArchived,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (bundles.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_off_outlined,
                size: 64,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary),
            const SizedBox(height: 16),
            Text(
              'No archived category bundles.',
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

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: bundles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final bundle = bundles[i];
        final bundleExercises = allArchived
            .where((e) => e.archivedCategoryBundleId == bundle.id)
            .toList();

        return Card(
          child: ExpansionTile(
            leading: Icon(Icons.folder_outlined,
                color: theme.colorScheme.primary),
            title: Text(bundle.name,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            subtitle: Text(
              'Archived ${DateFormat('MMM d, yyyy').format(bundle.archivedAt.toLocal())}  ·  '
              '${bundleExercises.length} exercise(s)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            // Restore all / delete bundle buttons
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.unarchive_outlined,
                      color: theme.colorScheme.primary),
                  tooltip: 'Restore all exercises',
                  onPressed: () => _restoreBundle(
                      context, ref, bundle, bundleExercises),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.error),
                  tooltip: 'Delete bundle permanently',
                  onPressed: () =>
                      _confirmDeleteBundle(context, ref, bundle),
                ),
              ],
            ),
            // Individual exercise rows with their own restore buttons
            children: bundleExercises
                .map((e) => _BundleExerciseRow(
                      exercise: e,
                      bundle: bundle,
                    ))
                .toList(),
          ),
        );
      },
    );
  }

  Future<void> _restoreBundle(
    BuildContext context,
    WidgetRef ref,
    ArchivedCategoryBundle bundle,
    List<Exercise> exercises,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restore Category?'),
        content: Text(
            'The category "${bundle.name}" and all ${exercises.length} '
            'exercise(s) inside it will be restored.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restore')),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(categoryRepositoryProvider)
          .restoreBundleAsCategory(bundle.id, bundle.name);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '"${bundle.name}" restored with ${exercises.length} exercise(s).')),
        );
      }
    }
  }

  Future<void> _confirmDeleteBundle(
    BuildContext context,
    WidgetRef ref,
    ArchivedCategoryBundle bundle,
  ) async {
    final ctrl = TextEditingController();
    bool confirmed = false;

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, _, __) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Permanently Delete Bundle?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'All exercises in this bundle will be permanently deleted. '
                'Type "${bundle.name}" to confirm.',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                decoration: InputDecoration(hintText: bundle.name),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white),
              onPressed:
                  NameValidator.isSameNormalized(ctrl.text, bundle.name)
                      ? () {
                          confirmed = true;
                          Navigator.pop(dialogContext);
                        }
                      : null,
              child: const Text('Delete Forever'),
            ),
          ],
        ),
      ),
    );

    ctrl.dispose();

    if (confirmed && context.mounted) {
      await ref
          .read(categoryRepositoryProvider)
          .deleteBundleWithExercises(bundle.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '"${bundle.name}" bundle permanently deleted.')),
        );
      }
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Single exercise row inside a bundle's expansion tile
// ──────────────────────────────────────────────────────────────────────────────
class _BundleExerciseRow extends ConsumerWidget {
  final Exercise exercise;
  final ArchivedCategoryBundle bundle;

  const _BundleExerciseRow({
    required this.exercise,
    required this.bundle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 24, right: 8),
      leading: const Icon(Icons.music_note_outlined, size: 18),
      title: Text(exercise.name, style: theme.textTheme.bodySmall),
      subtitle: exercise.lastBpm > 0
          ? Text('Last BPM: ${exercise.lastBpm}',
              style: theme.textTheme.labelSmall)
          : null,
      trailing: IconButton(
        icon: Icon(Icons.unarchive_outlined,
            size: 20, color: theme.colorScheme.primary),
        tooltip: 'Restore this exercise',
        onPressed: () => _restore(context, ref),
      ),
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final categories = ref.read(categoriesProvider).valueOrNull ?? [];
    final result =
        await _showCategoryPicker(context, categories, exercise.name);
    if (result == null || !context.mounted) return;

    await ref
        .read(exerciseRepositoryProvider)
        .restoreExercise(exercise.id, result.categoryId);

    if (context.mounted) {
      final dest = result.categoryId == null
          ? 'Uncategorized'
          : (categories
                  .where((c) => c.id == result.categoryId)
                  .firstOrNull
                  ?.name ??
              'category');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '"${exercise.name}" restored from "${bundle.name}" to $dest.')),
      );
    }
  }
}
