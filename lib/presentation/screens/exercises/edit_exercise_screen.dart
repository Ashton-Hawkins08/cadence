import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/constants/app_constants.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/data/database/app_database.dart';
import 'package:cadence/domain/validators/name_validator.dart';
import 'package:cadence/presentation/providers/database_provider.dart';
import 'package:cadence/presentation/providers/exercises_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:intl/intl.dart';

class EditExerciseScreen extends ConsumerStatefulWidget {
  final Exercise exercise;
  final List<Category> categories;
  final int initialTabIndex;

  const EditExerciseScreen({
    super.key,
    required this.exercise,
    required this.categories,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<EditExerciseScreen> createState() => _EditExerciseScreenState();
}

class _EditExerciseScreenState extends ConsumerState<EditExerciseScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _nameCtrl;
  late TextEditingController _reminderCtrl;
  late TextEditingController _initialBpmCtrl;
  late TextEditingController _goalBpmCtrl;
  late TextEditingController _noteCtrl;

  Category? _selectedCategory;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    final ex = widget.exercise;
    _nameCtrl = TextEditingController(text: ex.name);
    _reminderCtrl = TextEditingController(text: ex.reminderDays.toString());
    _initialBpmCtrl =
        TextEditingController(text: ex.initialBpm?.toString() ?? '');
    _goalBpmCtrl = TextEditingController(text: ex.goalBpm?.toString() ?? '');
    _noteCtrl = TextEditingController();

    _selectedCategory = widget.categories
        .where((c) => c.id == ex.categoryId)
        .firstOrNull;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _reminderCtrl.dispose();
    _initialBpmCtrl.dispose();
    _goalBpmCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveDetails() async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(exerciseRepositoryProvider);
      final ex = widget.exercise;
      final newName = NameValidator.sanitize(_nameCtrl.text);
      final reminderDays = (int.tryParse(_reminderCtrl.text) ?? ex.reminderDays)
          .clamp(1, AppConstants.maxReminderDays);
      final initialBpm = int.tryParse(_initialBpmCtrl.text);
      final goalBpm = int.tryParse(_goalBpmCtrl.text);

      // Validate name
      if (newName.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Exercise name cannot be empty.')),
          );
        }
        return;
      }

      // Validate BPM ranges
      if (initialBpm != null &&
          (initialBpm < AppConstants.minBpm ||
              initialBpm > AppConstants.maxBpm)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Starting BPM must be ${AppConstants.minBpm}–${AppConstants.maxBpm}.')),
          );
        }
        return;
      }
      if (goalBpm != null &&
          (goalBpm < AppConstants.minBpm || goalBpm > AppConstants.maxBpm)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Goal BPM must be ${AppConstants.minBpm}–${AppConstants.maxBpm}.')),
          );
        }
        return;
      }

      // Validate goal BPM pair
      if (initialBpm != null && goalBpm != null && goalBpm <= initialBpm) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Goal BPM must be above your starting BPM.')),
          );
        }
        return;
      }

      if (newName.toLowerCase() != ex.name.toLowerCase()) {
        final existing = await repo.getByName(newName);
        if (existing != null && existing.id != ex.id) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text('An exercise named "$newName" already exists.')),
            );
          }
          return;
        }
      }

      await repo.update(
        ex.id,
        ExercisesCompanion(
          name: Value(newName),
          categoryId: Value(_selectedCategory?.id),
          reminderDays: Value(reminderDays),
          initialBpm: Value(initialBpm),
          goalBpm: Value(goalBpm),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exercise updated.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addNote() async {
    final text = _noteCtrl.text.trim();
    if (text.isEmpty) return;
    if (text.length > AppConstants.maxNote) return;
    await ref.read(exerciseRepositoryProvider).addNote(widget.exercise.id, text);
    _noteCtrl.clear();
  }

  Future<void> _archive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Archive Exercise?'),
        content: Text(
            '"${widget.exercise.name}" will be moved to the Archive. '
            'You can restore it later.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Archive')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(exerciseRepositoryProvider)
          .archiveIndividually(widget.exercise.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final notesAsync =
        ref.watch(exerciseNotesProvider(widget.exercise.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exercise.name),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Details'),
            Tab(text: 'Notes'),
          ],
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: isDark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
          indicatorColor: theme.colorScheme.primary,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: 'Archive',
            onPressed: _archive,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Details Tab ────────────────────────────────────────────────────
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Name', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(),
              ),

              const SizedBox(height: 20),

              Text('Category', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              DropdownButtonFormField<Category?>(
                value: _selectedCategory,
                decoration: const InputDecoration(),
                hint: const Text('Uncategorized'),
                items: [
                  const DropdownMenuItem<Category?>(
                      value: null, child: Text('Uncategorized')),
                  ...widget.categories.map(
                      (c) => DropdownMenuItem(value: c, child: Text(c.name))),
                ],
                onChanged: (v) => setState(() => _selectedCategory = v),
              ),

              const SizedBox(height: 20),

              Text('Reminder Days', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reminderCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  hintText: '1 – 365',
                ),
              ),

              const SizedBox(height: 20),

              Text('Goal BPM', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _initialBpmCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Current'),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('→'),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: _goalBpmCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Goal'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      _initialBpmCtrl.clear();
                      _goalBpmCtrl.clear();
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveDetails,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ),

          // ── Notes Tab ──────────────────────────────────────────────────────
          Column(
            children: [
              // Add note input
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
                      icon: Icon(Icons.send,
                          color: theme.colorScheme.primary),
                      onPressed: _addNote,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Notes list
              Expanded(
                child: notesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
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
                              .read(exerciseRepositoryProvider)
                              .deleteNote(note.id),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('MMM d, yyyy').format(note.createdAt.toLocal()),
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
        ],
      ),
    );
  }
}
