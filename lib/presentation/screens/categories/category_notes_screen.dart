import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cadence/core/constants/app_constants.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/data/database/app_database.dart';
import 'package:cadence/presentation/providers/categories_provider.dart';
import 'package:cadence/presentation/providers/database_provider.dart';

class CategoryNotesScreen extends ConsumerStatefulWidget {
  final Category category;

  const CategoryNotesScreen({super.key, required this.category});

  @override
  ConsumerState<CategoryNotesScreen> createState() =>
      _CategoryNotesScreenState();
}

class _CategoryNotesScreenState extends ConsumerState<CategoryNotesScreen> {
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _addNote() async {
    final text = _noteCtrl.text.trim();
    if (text.isEmpty) return;
    if (text.length > AppConstants.maxNote) return;
    await ref
        .read(categoryRepositoryProvider)
        .addNote(widget.category.id, text);
    _noteCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final notesAsync =
        ref.watch(categoryNotesProvider(widget.category.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.category.name} — Notes'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _noteCtrl,
                    maxLength: AppConstants.maxNote,
                    decoration: const InputDecoration(
                      hintText: 'Add a note...',
                      counterText: '',
                    ),
                    onSubmitted: (_) => _addNote(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send, color: theme.colorScheme.primary),
                  onPressed: _addNote,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: notesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (notes) {
                if (notes.isEmpty) {
                  return Center(
                    child: Text(
                      'No notes yet.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: notes.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, i) {
                    final note = notes[i];
                    return Dismissible(
                      key: Key(note.id.toString()),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        color: AppColors.error,
                        child: const Icon(Icons.delete_outline,
                            color: Colors.white),
                      ),
                      confirmDismiss: (_) async {
                        return await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete Note?'),
                            content: const Text(
                                'This note will be permanently deleted.'),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel')),
                              ElevatedButton(
                                  onPressed: () =>
                                      Navigator.pop(context, true),
                                  child: const Text('Delete')),
                            ],
                          ),
                        );
                      },
                      onDismissed: (_) => ref
                          .read(categoryRepositoryProvider)
                          .deleteNote(note.id),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('MMM d, yyyy')
                                .format(note.createdAt.toLocal()),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(note.noteText,
                              style: theme.textTheme.bodyMedium),
                        ],
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
