import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cadence/core/constants/app_constants.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/data/database/app_database.dart';
import 'package:cadence/domain/validators/name_validator.dart';
import 'package:cadence/presentation/providers/database_provider.dart';
import 'package:cadence/presentation/providers/score_provider.dart';
import 'package:cadence/presentation/providers/settings_provider.dart';
import 'package:cadence/presentation/screens/metronome/piece_builder/piece_editor_screen.dart';
import 'package:cadence/presentation/screens/scores/score_viewer_screen.dart';
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

  // ── Scores & Pieces attachments ──────────────────────────────────────────
  // Sheet music and measure tracking are always exercise-owned: they are
  // created HERE (or later from the Scores & Pieces browser), never as
  // standalone items.
  bool _attachSheet = false;
  bool _measureTracking = false;
  final List<XFile> _pickedPages = [];
  final _picker = ImagePicker();

  Future<void> _pickSheetImages() async {
    final files = await _picker.pickMultiImage();
    if (files.isNotEmpty && mounted) {
      setState(() => _pickedPages.addAll(files));
    }
  }

  Future<void> _captureSheetImage() async {
    final shot = await _picker.pickImage(source: ImageSource.camera);
    if (shot != null && mounted) {
      setState(() => _pickedPages.add(shot));
    }
  }

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

      final exerciseId = await repo.create(
        ExercisesCompanion.insert(
          name: name,
          categoryId: Value(_selectedCategory?.id),
          reminderDays: Value(settings?.defaultReminderDays ??
              AppConstants.defaultReminderDays),
          initialBpm: Value(initialBpm),
          goalBpm: Value(goalBpm),
        ),
      );

      await _createAttachments(exerciseId, name);

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Creates the exercise-owned piece map and/or score folder, then walks
  /// the user through the follow-up steps: section design for the piece,
  /// and (when BOTH are attached) an optional page-turn setup pass.
  Future<void> _createAttachments(int exerciseId, String name) async {
    int? pieceId;
    if (_measureTracking) {
      pieceId = await ref
          .read(pieceRepositoryProvider)
          .create(name, exerciseId: exerciseId);
    }

    int? folderId;
    if (_attachSheet && _pickedPages.isNotEmpty) {
      final scoreRepo = ref.read(scoreRepositoryProvider);
      // linkedPieceId makes the rehearsal canvas play this exercise's piece
      // map automatically.
      folderId = await scoreRepo.createFolder(name,
          exerciseId: exerciseId, linkedPieceId: pieceId);
      for (var i = 0; i < _pickedPages.length; i++) {
        await scoreRepo.addPage(
          folderId: folderId,
          sourcePath: _pickedPages[i].path,
          name: 'Page ${i + 1}',
        );
      }
    }

    if (!mounted || pieceId == null) return;

    // Piece attached → design its sections now (same editor the piece
    // builder has always used, so the roadmap matches the sheet).
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PieceEditorScreen(pieceId: pieceId!, title: name),
      ),
    );

    if (!mounted || folderId == null) return;

    // Both attached → offer the page-turn pass. Declining is fine: the
    // canvas always allows manual swiping during playback.
    final setUpTurns = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Auto page turns?'),
        content: const Text(
            'Pick the measures where your sheet should flip to the next '
            'page while the piece plays. You can skip this and simply '
            'swipe pages yourself during playback.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Swipe manually')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Pick measures')),
        ],
      ),
    );
    if (setUpTurns != true || !mounted) return;

    final folder =
        await ref.read(scoreRepositoryProvider).getFolderById(folderId);
    if (folder == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScoreViewerScreen(folder: folder, openTurnEditor: true),
      ),
    );
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

            const SizedBox(height: 24),

            // ── Attach Sheet Music ─────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Attach Sheet Music', style: theme.textTheme.labelLarge),
                Switch(
                  value: _attachSheet,
                  onChanged: (v) => setState(() => _attachSheet = v),
                  activeColor: theme.colorScheme.primary,
                ),
              ],
            ),
            if (_attachSheet) ...[
              const SizedBox(height: 4),
              Text(
                'Import your score pages — they open in the rehearsal canvas '
                'with annotation tools and the metronome.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickSheetImages,
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Files / Images'),
                  ),
                  if (Platform.isAndroid || Platform.isIOS) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _captureSheetImage,
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('Camera'),
                    ),
                  ],
                ],
              ),
              if (_pickedPages.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 72,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _pickedPages.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(
                            File(_pickedPages[i].path),
                            width: 54,
                            height: 72,
                            fit: BoxFit.cover,
                            cacheWidth: 120,
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _pickedPages.removeAt(i)),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],

            const SizedBox(height: 24),

            // ── Measure Tracking (piece map) ───────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Measure Tracking', style: theme.textTheme.labelLarge),
                Switch(
                  value: _measureTracking,
                  onChanged: (v) => setState(() => _measureTracking = v),
                  activeColor: theme.colorScheme.primary,
                ),
              ],
            ),
            if (_measureTracking) ...[
              const SizedBox(height: 4),
              Text(
                'Adds a piece map: after saving, you\'ll design its sections '
                '(measure ranges, tempo, time signature) so the metronome '
                'follows your music${_attachSheet ? ' — and can turn your sheet pages at the measures you pick' : ''}.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.indigoNavySoft,
                ),
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
