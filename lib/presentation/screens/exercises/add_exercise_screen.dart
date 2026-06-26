import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/constants/app_constants.dart';
import 'package:cadence/data/database/app_database.dart';
import 'package:cadence/domain/validators/name_validator.dart';
import 'package:cadence/presentation/providers/database_provider.dart';
import 'package:cadence/presentation/providers/settings_provider.dart';
import 'package:drift/drift.dart' show Value;

class AddExerciseScreen extends ConsumerStatefulWidget {
  final List<Category> categories;
  final int? initialCategoryId;
  const AddExerciseScreen({
    super.key,
    required this.categories,
    this.initialCategoryId,
  });

  @override
  ConsumerState<AddExerciseScreen> createState() => _AddExerciseScreenState();
}

class _AddExerciseScreenState extends ConsumerState<AddExerciseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _initialBpmCtrl = TextEditingController();
  final _goalBpmCtrl = TextEditingController();

  Category? _selectedCategory;
  bool _setGoal = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCategoryId != null) {
      _selectedCategory = widget.categories
          .where((c) => c.id == widget.initialCategoryId)
          .firstOrNull;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _initialBpmCtrl.dispose();
    _goalBpmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final repo = ref.read(exerciseRepositoryProvider);
      final settings = ref.read(settingsProvider).valueOrNull;
      final name = NameValidator.sanitize(_nameCtrl.text);

      // Collision check against active exercises
      final existing = await repo.getByName(name);
      if (existing != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('An exercise named "$name" already exists.')),
          );
        }
        return;
      }

      int? initialBpm;
      int? goalBpm;
      if (_setGoal) {
        initialBpm = int.tryParse(_initialBpmCtrl.text);
        goalBpm = int.tryParse(_goalBpmCtrl.text);
      }

      await repo.create(
        ExercisesCompanion.insert(
          name: name,
          categoryId: Value(_selectedCategory?.id),
          reminderDays: Value(settings?.defaultReminderDays ??
              AppConstants.defaultReminderDays),
          initialBpm: Value(initialBpm),
          goalBpm: Value(goalBpm),
        ),
      );

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Exercise')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Name
            Text('Exercise Name', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g. Helicopters, Crossovers',
              ),
              validator: NameValidator.validate,
            ),

            const SizedBox(height: 24),

            // Category
            Text('Category', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            DropdownButtonFormField<Category?>(
              value: _selectedCategory,
              decoration: const InputDecoration(),
              hint: const Text('Uncategorized'),
              items: [
                const DropdownMenuItem<Category?>(
                  value: null,
                  child: Text('Uncategorized'),
                ),
                ...widget.categories.map(
                  (c) => DropdownMenuItem(value: c, child: Text(c.name)),
                ),
              ],
              onChanged: (v) => setState(() => _selectedCategory = v),
            ),

            const SizedBox(height: 24),

            // Goal BPM toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Set Goal BPM', style: theme.textTheme.labelLarge),
                Switch(
                  value: _setGoal,
                  onChanged: (v) => setState(() => _setGoal = v),
                  activeColor: theme.colorScheme.primary,
                ),
              ],
            ),

            if (_setGoal) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _initialBpmCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Current BPM',
                  hintText: '1 – 300',
                ),
                validator: (v) {
                  if (!_setGoal) return null;
                  final n = int.tryParse(v ?? '');
                  if (n == null ||
                      n < AppConstants.minBpm ||
                      n > AppConstants.maxBpm) {
                    return 'Enter a BPM between ${AppConstants.minBpm} and ${AppConstants.maxBpm}.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _goalBpmCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Goal BPM',
                  hintText: 'Must be above current BPM',
                ),
                validator: (v) {
                  if (!_setGoal) return null;
                  final goal = int.tryParse(v ?? '');
                  final initial = int.tryParse(_initialBpmCtrl.text);
                  if (goal == null ||
                      goal < AppConstants.minBpm ||
                      goal > AppConstants.maxBpm) {
                    return 'Enter a BPM between ${AppConstants.minBpm} and ${AppConstants.maxBpm}.';
                  }
                  if (initial != null && goal <= initial) {
                    return 'Goal must be above your current BPM ($initial).';
                  }
                  return null;
                },
              ),
            ],

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Add Exercise'),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
