import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/core/constants/app_constants.dart';
import 'package:cadence/core/constants/metronome_constants.dart';
import 'package:cadence/data/database/app_database.dart';
import 'package:cadence/presentation/providers/database_provider.dart';
import 'package:cadence/presentation/providers/piece_provider.dart';
import 'piece_player_screen.dart';

// ── Section draft ─────────────────────────────────────────────────────────────

class _SectionDraft {
  int endMeasure;
  int bpm;
  MetronomeTimeSignature timeSignature;
  MetronomeSubdivision subdivision;
  bool accentFirstBeat;

  _SectionDraft({
    required this.endMeasure,
    required this.bpm,
    required this.timeSignature,
    required this.subdivision,
    this.accentFirstBeat = true,
  });
}

// ── Piece editor ──────────────────────────────────────────────────────────────

class PieceEditorScreen extends ConsumerStatefulWidget {
  final int pieceId;
  final String title;

  const PieceEditorScreen(
      {super.key, required this.pieceId, required this.title});

  @override
  ConsumerState<PieceEditorScreen> createState() => _PieceEditorScreenState();
}

class _PieceEditorScreenState extends ConsumerState<PieceEditorScreen> {
  List<_SectionDraft>? _drafts;
  bool _dirty = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sectionsAsync = ref.watch(pieceSectionsProvider(widget.pieceId));

    return sectionsAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (sections) {
        _drafts ??= sections
            .map((s) => _SectionDraft(
                  endMeasure: s.endMeasure,
                  bpm: s.bpm,
                  timeSignature: MetronomeTimeSignature.values.firstWhere(
                      (v) => v.name == s.timeSignature,
                      orElse: () => MetronomeTimeSignature.sig4_4),
                  subdivision: MetronomeSubdivision.values.firstWhere(
                      (v) => v.name == s.subdivision,
                      orElse: () => MetronomeSubdivision.quarter),
                  accentFirstBeat: s.accentFirstBeat,
                ))
            .toList();

        final drafts = _drafts!;
        final error = _validationError(drafts);

        return Scaffold(
          backgroundColor:
              isDark ? AppColors.darkBackground : AppColors.lightBackground,
          appBar: AppBar(
            backgroundColor:
                isDark ? AppColors.darkSurface : AppColors.lightSurface,
            elevation: 0,
            title: Text(widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            actions: [
              if (drafts.isNotEmpty)
                TextButton.icon(
                  onPressed: error == null ? () => _play(context, drafts) : null,
                  icon: const Icon(Icons.play_circle_fill,
                      color: AppColors.indigoNavySoft),
                  label: const Text('Play',
                      style: TextStyle(color: AppColors.indigoNavySoft)),
                ),
              TextButton(
                onPressed: (_dirty && error == null)
                    ? () => _save(drafts)
                    : null,
                child: Text('Save',
                    style: TextStyle(
                        color: (_dirty && error == null)
                            ? AppColors.indigoNavySoft
                            : Colors.transparent)),
              ),
            ],
          ),
          body: Column(
            children: [
              if (error != null) _ErrorBanner(message: error),
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  // Disable built-in drag handles — they overlap the BPM field
                  buildDefaultDragHandles: false,
                  itemCount: drafts.length,
                  itemBuilder: (context, i) => _SectionCard(
                    key: ValueKey(i),
                    index: i,
                    draft: drafts[i],
                    startMeasure: _startMeasureFor(drafts, i),
                    isDark: isDark,
                    theme: theme,
                    onChanged: () => setState(() => _dirty = true),
                    onDelete: () => setState(() {
                      drafts.removeAt(i);
                      _dirty = true;
                    }),
                  ),
                  onReorderItem: (oldIndex, newIndex) {
                    setState(() {
                      final item = drafts.removeAt(oldIndex);
                      drafts.insert(newIndex, item);
                      _dirty = true;
                    });
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _addSection,
            backgroundColor: AppColors.indigoNavy,
            icon: const Icon(Icons.add),
            label: const Text('Add Section'),
          ),
        );
      },
    );
  }

  int _startMeasureFor(List<_SectionDraft> drafts, int index) {
    if (index == 0) return 1;
    return drafts[index - 1].endMeasure + 1;
  }

  String? _validationError(List<_SectionDraft> drafts) {
    for (int i = 0; i < drafts.length; i++) {
      final start = _startMeasureFor(drafts, i);
      if (drafts[i].endMeasure < start) {
        return 'Section ${i + 1}: end measure must be ≥ $start';
      }
    }
    return null;
  }

  void _addSection() {
    final drafts = _drafts!;
    final lastEnd = drafts.isEmpty ? 0 : drafts.last.endMeasure;
    final prev = drafts.isEmpty ? null : drafts.last;
    setState(() {
      drafts.add(_SectionDraft(
        endMeasure: lastEnd + 4,
        bpm: prev?.bpm ?? 120,
        timeSignature: prev?.timeSignature ?? MetronomeTimeSignature.sig4_4,
        subdivision: prev?.subdivision ?? MetronomeSubdivision.quarter,
        accentFirstBeat: prev?.accentFirstBeat ?? true,
      ));
      _dirty = true;
    });
  }

  Future<void> _save(List<_SectionDraft> drafts) async {
    if (_validationError(drafts) != null) return;
    final repo = ref.read(pieceRepositoryProvider);
    final companions = drafts.asMap().entries.map((e) {
      final i = e.key;
      final d = e.value;
      return PieceSectionsCompanion.insert(
        pieceId: widget.pieceId,
        sortOrder: i,
        startMeasure: _startMeasureFor(drafts, i),
        endMeasure: d.endMeasure,
        bpm: d.bpm,
        timeSignature: d.timeSignature.name,
        subdivision: d.subdivision.name,
        accentFirstBeat: Value(d.accentFirstBeat),
      );
    }).toList();
    await repo.replaceSections(widget.pieceId, companions);
    if (!mounted) return;
    setState(() => _dirty = false);
  }

  void _play(BuildContext context, List<_SectionDraft> drafts) {
    if (_dirty) {
      _save(drafts).then((_) {
        if (!context.mounted) return;
        _pushPlayer(context);
      }).catchError((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save before playing.')),
        );
      });
    } else {
      _pushPlayer(context);
    }
  }

  void _pushPlayer(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            PiecePlayerScreen(pieceId: widget.pieceId, title: widget.title)));
  }
}

// ── Section card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatefulWidget {
  final int index;
  final _SectionDraft draft;
  final int startMeasure;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _SectionCard({
    super.key,
    required this.index,
    required this.draft,
    required this.startMeasure,
    required this.isDark,
    required this.theme,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  late TextEditingController _bpmCtrl;
  late TextEditingController _endCtrl;

  @override
  void initState() {
    super.initState();
    _bpmCtrl = TextEditingController(text: widget.draft.bpm.toString());
    _endCtrl =
        TextEditingController(text: widget.draft.endMeasure.toString());
  }

  @override
  void didUpdateWidget(covariant _SectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reorder swaps which draft object this State holds; sync controllers.
    if (oldWidget.draft != widget.draft) {
      _bpmCtrl.text = widget.draft.bpm.toString();
      _endCtrl.text = widget.draft.endMeasure.toString();
    }
  }

  @override
  void dispose() {
    _bpmCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final isDark = widget.isDark;
    final theme = widget.theme;

    return Card(
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: label + drag handle + delete ──────────────────────
            Row(
              children: [
                Text('Section ${widget.index + 1}',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                // Explicit drag handle — avoids overlap with BPM field
                ReorderableDragStartListener(
                  index: widget.index,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.drag_handle,
                        color: AppColors.indigoNavySoft),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: widget.onDelete,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Measure range ─────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _LabeledField(
                    isDark: isDark,
                    label: 'Start',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('M${widget.startMeasure}',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LabeledField(
                    isDark: isDark,
                    label: 'End Measure',
                    child: TextField(
                      controller: _endCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      decoration: const InputDecoration(
                        prefixText: 'M',
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                      ),
                      onChanged: (v) {
                        final parsed = int.tryParse(v);
                        if (parsed != null) {
                          d.endMeasure = parsed;
                          widget.onChanged();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── BPM ───────────────────────────────────────────────────────
            _LabeledField(
              isDark: isDark,
              label: 'BPM',
              child: Row(
                children: [
                  Expanded(
                    child: Slider(
                      min: AppConstants.minBpm.toDouble(),
                      max: AppConstants.maxBpm.toDouble(),
                      value: d.bpm
                          .clamp(AppConstants.minBpm, AppConstants.maxBpm)
                          .toDouble(),
                      activeColor: AppColors.indigoNavySoft,
                      inactiveColor: isDark
                          ? AppColors.darkDivider
                          : AppColors.lightDivider,
                      onChanged: (v) {
                        setState(() => d.bpm = v.round());
                        _bpmCtrl.text = d.bpm.toString();
                        widget.onChanged();
                      },
                    ),
                  ),
                  // BPM text field — 56px, no overlap
                  SizedBox(
                    width: 56,
                    child: TextField(
                      controller: _bpmCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (v) {
                        final parsed = int.tryParse(v);
                        if (parsed != null) {
                          final clamped = parsed.clamp(
                              AppConstants.minBpm, AppConstants.maxBpm);
                          setState(() => d.bpm = clamped);
                          if (clamped != parsed) {
                            _bpmCtrl.text = clamped.toString();
                            _bpmCtrl.selection = TextSelection.fromPosition(
                                TextPosition(offset: _bpmCtrl.text.length));
                          }
                          widget.onChanged();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Time Signature ────────────────────────────────────────────
            _LabeledField(
              isDark: isDark,
              label: 'Time Signature',
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: MetronomeTimeSignature.values.map((ts) {
                  final sel = ts == d.timeSignature;
                  return ChoiceChip(
                    label: Text(ts.display),
                    selected: sel,
                    onSelected: (_) {
                      setState(() {
                        d.timeSignature = ts;
                        final subs = ts.availableSubdivisions;
                        if (!subs.contains(d.subdivision)) {
                          d.subdivision = subs.first;
                        }
                      });
                      widget.onChanged();
                    },
                    selectedColor: AppColors.indigoNavySoft,
                    backgroundColor: isDark
                        ? AppColors.darkBackground
                        : AppColors.lightBackground,
                    labelStyle: TextStyle(
                        color: sel ? Colors.white : null, fontSize: 11),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // ── Subdivision ───────────────────────────────────────────────
            _LabeledField(
              isDark: isDark,
              label: 'Subdivision',
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: d.timeSignature.availableSubdivisions.map((sub) {
                  final sel = sub == d.subdivision;
                  return ChoiceChip(
                    label: Text(sub.displayName),
                    selected: sel,
                    onSelected: (_) {
                      setState(() => d.subdivision = sub);
                      widget.onChanged();
                    },
                    selectedColor: AppColors.indigoNavySoft,
                    backgroundColor: isDark
                        ? AppColors.darkBackground
                        : AppColors.lightBackground,
                    labelStyle: TextStyle(
                        color: sel ? Colors.white : null, fontSize: 11),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),

            // ── Accent first beat ─────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Accent First Beat',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary)),
                Switch(
                  value: d.accentFirstBeat,
                  onChanged: (v) {
                    setState(() => d.accentFirstBeat = v);
                    widget.onChanged();
                  },
                  activeColor: AppColors.indigoNavySoft,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Labeled field ─────────────────────────────────────────────────────────────

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  final bool isDark;

  const _LabeledField(
      {required this.label, required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary)),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: AppColors.error.withValues(alpha: 0.12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text(message,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.error)),
      );
}
