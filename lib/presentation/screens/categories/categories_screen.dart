import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/data/database/app_database.dart';
import 'package:cadence/domain/validators/name_validator.dart';
import 'package:cadence/presentation/providers/categories_provider.dart';
import 'package:cadence/presentation/providers/database_provider.dart';
import 'package:cadence/presentation/providers/exercises_provider.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final categoriesAsync = ref.watch(categoriesProvider);
    final exercisesAsync = ref.watch(exercisesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        leading: const BackButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Category',
            onPressed: () => _showAddDialog(context, ref),
          ),
        ],
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (categories) {
          final exercises = exercisesAsync.valueOrNull ?? [];

          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_outlined,
                      size: 64,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary),
                  const SizedBox(height: 16),
                  Text(
                    'No categories yet.\nTap + to create one.',
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

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final cat = categories[i];
              final catExercises =
                  exercises.where((e) => e.categoryId == cat.id).toList();
              final withBpm =
                  catExercises.where((e) => e.lastBpm > 0).toList();
              final avgBpm = withBpm.isEmpty
                  ? null
                  : withBpm.map((e) => e.lastBpm).fold<int>(0, (a, b) => a + b) /
                      withBpm.length;

              return Card(
                child: ListTile(
                  leading: Icon(Icons.folder_outlined,
                      color: theme.colorScheme.primary),
                  title: Text(cat.name,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    [
                      '${catExercises.length} exercise(s)',
                      if (avgBpm != null)
                        'Avg BPM: ${avgBpm.toStringAsFixed(0)}',
                    ].join('  ·  '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary),
                    onSelected: (action) {
                      if (action == 'rename') {
                        _showRenameDialog(context, ref, cat);
                      } else if (action == 'delete') {
                        _showDeleteDialog(context, ref, cat);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'rename', child: Text('Rename')),
                      PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete',
                              style: TextStyle(color: AppColors.error))),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final existing = (ref.read(categoriesProvider).valueOrNull ?? [])
        .map((c) => c.name)
        .toList();
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
            child: const Text('Create'),
          ),
        ],
      ),
    );

    ctrl.dispose();

    if (savedName != null && context.mounted) {
      await ref.read(categoryRepositoryProvider).create(savedName!);
    }
  }

  Future<void> _showRenameDialog(
      BuildContext context, WidgetRef ref, Category cat) async {
    final ctrl = TextEditingController(text: cat.name);
    final formKey = GlobalKey<FormState>();
    final existing = (ref.read(categoriesProvider).valueOrNull ?? [])
        .where((c) => c.id != cat.id)
        .map((c) => c.name)
        .toList();
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
            decoration: const InputDecoration(),
            validator: (v) {
              final err = NameValidator.validate(v);
              if (err != null) return err;
              if (NameValidator.isSameNormalized(v!.trim(), cat.name)) {
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
                  ctrl.text.trim(), cat.name)) {
                savedName = NameValidator.sanitize(ctrl.text);
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
      await ref.read(categoryRepositoryProvider).rename(cat.id, savedName!);
    }
  }

  Future<void> _showDeleteDialog(
      BuildContext context, WidgetRef ref, Category cat) async {
    final confirmCtrl = TextEditingController();
    bool confirmed = false;

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, _, __) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Delete Category?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Exercises in "${cat.name}" will be archived as a bundle. '
                'Type the category name to confirm.',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmCtrl,
                decoration: InputDecoration(hintText: cat.name),
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
                  NameValidator.isSameNormalized(confirmCtrl.text, cat.name)
                      ? () {
                          confirmed = true;
                          Navigator.pop(dialogContext);
                        }
                      : null,
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );

    confirmCtrl.dispose();

    if (confirmed && context.mounted) {
      await ref
          .read(categoryRepositoryProvider)
          .deleteWithBundle(cat.id, cat.name);
    }
  }
}
