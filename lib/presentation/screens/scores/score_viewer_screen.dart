import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/core/constants/metronome_constants.dart';
import 'package:cadence/data/database/app_database.dart';
import 'package:cadence/domain/models/score_annotation.dart';
import 'package:cadence/presentation/providers/database_provider.dart';
import 'package:cadence/presentation/providers/metronome_provider.dart';
import 'package:cadence/presentation/providers/score_provider.dart';
import 'annotation_canvas.dart';

// ── Rehearsal Canvas ──────────────────────────────────────────────────────────
//
// The score viewer where everything meets:
//   • swipable PageView of score images with pinch zoom
//   • vector annotation layer per page (pen / highlighter / stroke eraser),
//     persisted as normalized-coordinate JSON — instant repaint on return
//   • sheet visibility toggle → collapses to a minimal metronome dashboard
//   • metronome transport; if the folder links a Piece Profile, its section
//     roadmap drives tempo/time-signature changes automatically
//   • auto page turner: "advance to page P at measure M" triggers, fired by
//     the engine's live measure counter
//
// Timing note: the beat clock lives on the NATIVE audio thread. This screen
// only consumes the ~4 ms visual state stream, so a page-turn animation can
// never perturb beat scheduling.

class ScoreViewerScreen extends ConsumerStatefulWidget {
  final ScoreFolder folder;
  final int initialPage;

  const ScoreViewerScreen({
    super.key,
    required this.folder,
    this.initialPage = 0,
  });

  @override
  ConsumerState<ScoreViewerScreen> createState() => _ScoreViewerScreenState();
}

class _ScoreViewerScreenState extends ConsumerState<ScoreViewerScreen> {
  late final PageController _pageCtrl;
  StreamSubscription<MetronomeState>? _stateSub;

  // Sheet visibility (spec: toggle to a minimal audio-only dashboard)
  bool _sheetVisible = true;

  // Annotation state
  bool _drawMode = false;
  AnnotationToolConfig _tool = const AnnotationToolConfig();
  final Map<int, List<ScoreStroke>> _strokes = {}; // pageId → strokes
  final Map<int, List<List<ScoreStroke>>> _undoStacks = {};
  final Map<String, Size> _imageSizeCache = {};

  // Auto page turner
  int _lastAutoPage = -1;

  MetronomeEngine get _engine => ref.read(metronomeEngineProvider);

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(initialPage: widget.initialPage);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadAnnotations();
      _stateSub = _engine.stateStream.listen(_onMetronomeState);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _engine.stop();
    _pageCtrl.dispose();
    super.dispose();
  }

  // ── Annotations ────────────────────────────────────────────────────────────

  Future<void> _preloadAnnotations() async {
    final repo = ref.read(scoreRepositoryProvider);
    final pages = await repo.getPages(widget.folder.id);
    for (final p in pages) {
      final json = await repo.getAnnotationJson(p.id);
      if (!mounted) return;
      setState(() => _strokes[p.id] = ScoreStroke.decodeList(json));
    }
  }

  void _onStrokesChanged(int pageId, List<ScoreStroke> next) {
    final prev = _strokes[pageId] ?? [];
    (_undoStacks[pageId] ??= []).add(prev);
    if (_undoStacks[pageId]!.length > 20) _undoStacks[pageId]!.removeAt(0);
    setState(() => _strokes[pageId] = next);
    // Persist immediately — stroke JSON is tiny, and losing markings to a
    // crash mid-rehearsal is far worse than one small write per stroke.
    unawaited(ref
        .read(scoreRepositoryProvider)
        .saveAnnotationJson(pageId, ScoreStroke.encodeList(next))
        .catchError((_) {}));
  }

  void _undo(int pageId) {
    final stack = _undoStacks[pageId];
    if (stack == null || stack.isEmpty) return;
    final prev = stack.removeLast();
    setState(() => _strokes[pageId] = prev);
    unawaited(ref
        .read(scoreRepositoryProvider)
        .saveAnnotationJson(pageId, ScoreStroke.encodeList(prev))
        .catchError((_) {}));
  }

  // ── Metronome / auto page turns ────────────────────────────────────────────

  void _onMetronomeState(MetronomeState s) {
    if (!s.isPlaying) {
      _lastAutoPage = -1;
      return;
    }
    final turns =
        ref.read(scoreTurnsProvider(widget.folder.id)).valueOrNull ?? [];
    if (turns.isEmpty) return;

    // Highest trigger at or below the current measure wins — this stays
    // correct even if a whole measure of state emissions was missed.
    ScorePageTurn? active;
    for (final t in turns) {
      if (t.measure <= s.currentMeasure) {
        active = t;
      } else {
        break; // turns are measure-ordered
      }
    }
    if (active == null || active.pageIndex == _lastAutoPage) return;
    _lastAutoPage = active.pageIndex;

    if (_pageCtrl.hasClients &&
        _pageCtrl.page?.round() != active.pageIndex &&
        _sheetVisible) {
      _pageCtrl.animateToPage(
        active.pageIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _play() async {
    final pieceId = widget.folder.linkedPieceId;
    if (pieceId != null) {
      final sections =
          await ref.read(pieceRepositoryProvider).getSectionsForPiece(pieceId);
      if (sections.isNotEmpty) {
        _engine.start(
          sections: sections
              .map((s) => SectionConfig(
                    startMeasure: s.startMeasure,
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
              .toList(),
        );
        return;
      }
    }
    _engine.start();
  }

  // ── Page turn trigger editor ───────────────────────────────────────────────

  Future<void> _editTurns(List<ScorePage> pages) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _TurnEditorSheet(
        folderId: widget.folder.id,
        pages: pages,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pagesAsync = ref.watch(scorePagesProvider(widget.folder.id));
    final stateAsync = ref.watch(metronomeStateProvider);
    final turns =
        ref.watch(scoreTurnsProvider(widget.folder.id)).valueOrNull ?? [];

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
        title: Text(widget.folder.name,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: _sheetVisible ? 'Hide sheet music' : 'Show sheet music',
            icon: Icon(
                _sheetVisible ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() {
              _sheetVisible = !_sheetVisible;
              if (!_sheetVisible) _drawMode = false;
            }),
          ),
          if (_sheetVisible)
            IconButton(
              tooltip: 'Auto page turns',
              icon: Badge(
                isLabelVisible: turns.isNotEmpty,
                label: Text('${turns.length}'),
                child: const Icon(Icons.auto_stories_outlined),
              ),
              onPressed: () async {
                final pages = pagesAsync.valueOrNull ?? [];
                if (pages.isNotEmpty) await _editTurns(pages);
              },
            ),
          if (_sheetVisible)
            IconButton(
              tooltip: _drawMode ? 'Done annotating' : 'Annotate',
              icon: Icon(_drawMode ? Icons.check : Icons.draw_outlined,
                  color: _drawMode ? AppColors.streakGold : null),
              onPressed: () => setState(() => _drawMode = !_drawMode),
            ),
        ],
      ),
      body: pagesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (pages) {
          if (pages.isEmpty) {
            return const Center(child: Text('This folder has no pages.'));
          }
          return Column(
            children: [
              Expanded(
                child: _sheetVisible
                    ? _buildSheetView(pages, isDark)
                    : _MiniDashboard(
                        stateAsync: stateAsync,
                        isDark: isDark,
                        linkedPiece: widget.folder.linkedPieceId != null,
                      ),
              ),
              if (_drawMode && _sheetVisible)
                _AnnotationToolbar(
                  config: _tool,
                  isDark: isDark,
                  onChanged: (c) => setState(() => _tool = c),
                  onUndo: () {
                    final idx = _pageCtrl.page?.round() ?? 0;
                    if (idx < pages.length) _undo(pages[idx].id);
                  },
                ),
              _TransportBar(
                stateAsync: stateAsync,
                isDark: isDark,
                pageCtrl: _pageCtrl,
                pageCount: pages.length,
                onPlay: _play,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSheetView(List<ScorePage> pages, bool isDark) {
    return PageView.builder(
      controller: _pageCtrl,
      // Swiping and drawing are mutually exclusive gestures.
      physics: _drawMode
          ? const NeverScrollableScrollPhysics()
          : const ClampingScrollPhysics(),
      itemCount: pages.length,
      itemBuilder: (_, i) {
        final page = pages[i];
        return _ScorePageView(
          page: page,
          strokes: _strokes[page.id] ?? const [],
          drawMode: _drawMode,
          tool: _tool,
          sizeCache: _imageSizeCache,
          onStrokesChanged: (s) => _onStrokesChanged(page.id, s),
        );
      },
    );
  }
}

// ── Single page: image + annotation layer, zoomable ──────────────────────────

class _ScorePageView extends StatelessWidget {
  final ScorePage page;
  final List<ScoreStroke> strokes;
  final bool drawMode;
  final AnnotationToolConfig tool;
  final Map<String, Size> sizeCache;
  final void Function(List<ScoreStroke>) onStrokesChanged;

  const _ScorePageView({
    required this.page,
    required this.strokes,
    required this.drawMode,
    required this.tool,
    required this.sizeCache,
    required this.onStrokesChanged,
  });

  Future<Size> _imageSize() async {
    final cached = sizeCache[page.imagePath];
    if (cached != null) return cached;
    final bytes = await File(page.imagePath).readAsBytes();
    final img = await decodeImageFromList(bytes);
    final size = Size(img.width.toDouble(), img.height.toDouble());
    img.dispose();
    sizeCache[page.imagePath] = size;
    return size;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Size>(
      future: _imageSize(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final imgSize = snap.data!;
        // The annotation layer is sized to EXACTLY the image rect (via
        // AspectRatio), so normalized stroke coordinates always land on the
        // same spot of the music regardless of device or zoom.
        return InteractiveViewer(
          minScale: 1.0,
          maxScale: 5.0,
          panEnabled: !drawMode,
          scaleEnabled: !drawMode,
          child: Center(
            child: AspectRatio(
              aspectRatio: imgSize.width / imgSize.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(File(page.imagePath), fit: BoxFit.fill),
                  AnnotationCanvas(
                    strokes: strokes,
                    drawEnabled: drawMode,
                    config: tool,
                    onChanged: onStrokesChanged,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Annotation toolbar ────────────────────────────────────────────────────────

class _AnnotationToolbar extends StatelessWidget {
  final AnnotationToolConfig config;
  final bool isDark;
  final void Function(AnnotationToolConfig) onChanged;
  final VoidCallback onUndo;

  const _AnnotationToolbar({
    required this.config,
    required this.isDark,
    required this.onChanged,
    required this.onUndo,
  });

  static const _palette = [
    Color(0xFF04006B), // indigo navy
    Color(0xFFE53935), // red
    Color(0xFF43A047), // green
    Color(0xFFFFD700), // gold
    Color(0xFF000000), // black
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isDark ? AppColors.darkNavBar : AppColors.lightNavBar,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.edit,
                size: 20,
                color: !config.eraser && config.tool == StrokeTool.pen
                    ? AppColors.indigoNavySoft
                    : null),
            tooltip: 'Pen',
            onPressed: () =>
                onChanged(config.copyWith(tool: StrokeTool.pen, eraser: false)),
          ),
          IconButton(
            icon: Icon(Icons.border_color,
                size: 20,
                color: !config.eraser && config.tool == StrokeTool.highlighter
                    ? AppColors.indigoNavySoft
                    : null),
            tooltip: 'Highlighter',
            onPressed: () => onChanged(
                config.copyWith(tool: StrokeTool.highlighter, eraser: false)),
          ),
          IconButton(
            icon: Icon(Icons.cleaning_services,
                size: 20,
                color: config.eraser ? AppColors.error : null),
            tooltip: 'Eraser (removes whole strokes)',
            onPressed: () => onChanged(config.copyWith(eraser: true)),
          ),
          const SizedBox(width: 4),
          ..._palette.map((c) => GestureDetector(
                onTap: () => onChanged(config.copyWith(color: c, eraser: false)),
                child: Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: config.color.toARGB32() == c.toARGB32() &&
                              !config.eraser
                          ? AppColors.streakGold
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
              )),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.undo, size: 20),
            tooltip: 'Undo',
            onPressed: onUndo,
          ),
        ],
      ),
    );
  }
}

// ── Minimal dashboard (sheet hidden) ─────────────────────────────────────────

class _MiniDashboard extends StatelessWidget {
  final AsyncValue<MetronomeState> stateAsync;
  final bool isDark;
  final bool linkedPiece;

  const _MiniDashboard({
    required this.stateAsync,
    required this.isDark,
    required this.linkedPiece,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = stateAsync.valueOrNull;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${state?.bpm ?? "—"}',
            style: theme.textTheme.displayLarge?.copyWith(
              fontSize: 96,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkText : AppColors.indigoNavy,
            ),
          ),
          Text('BPM',
              style: theme.textTheme.bodyMedium?.copyWith(
                letterSpacing: 3,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              )),
          const SizedBox(height: 20),
          if (state != null && state.isPlaying) ...[
            Text(
              'Measure ${state.currentMeasure}'
              '${linkedPiece ? '  ·  ${state.timeSignature.display}' : ''}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.indigoNavySoft,
              ),
            ),
            const SizedBox(height: 16),
            // Beat dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                state.visualTotalBeats.clamp(1, 12),
                (i) => Container(
                  width: i == 0 ? 16 : 12,
                  height: i == 0 ? 16 : 12,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: state.isPlaying && i == state.visualBeatIndex
                        ? AppColors.indigoNavySoft
                        : (isDark
                            ? AppColors.darkDivider
                            : AppColors.lightDivider),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Transport bar ─────────────────────────────────────────────────────────────

class _TransportBar extends ConsumerWidget {
  final AsyncValue<MetronomeState> stateAsync;
  final bool isDark;
  final PageController pageCtrl;
  final int pageCount;
  final Future<void> Function() onPlay;

  const _TransportBar({
    required this.stateAsync,
    required this.isDark,
    required this.pageCtrl,
    required this.pageCount,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = stateAsync.valueOrNull;
    final engine = ref.read(metronomeEngineProvider);
    final playing = state?.isPlaying ?? false;
    final paused = state?.isPaused ?? false;

    return Container(
      color: isDark ? AppColors.darkNavBar : AppColors.lightNavBar,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Play / pause
            GestureDetector(
              onTap: () {
                if (!playing && !paused) {
                  onPlay();
                } else if (playing && !paused) {
                  engine.pause();
                } else {
                  engine.resume();
                }
              },
              child: Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.indigoNavy,
                ),
                child: Icon(
                  playing && !paused ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (playing || paused)
              IconButton(
                onPressed: engine.stop,
                icon: const Icon(Icons.stop_circle_outlined, size: 30),
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            const Spacer(),
            if (state != null && (playing || paused))
              _chip(theme, 'M.${state.currentMeasure}'),
            const SizedBox(width: 6),
            _chip(theme, '♩ ${state?.bpm ?? "—"}'),
            const SizedBox(width: 6),
            AnimatedBuilder(
              animation: pageCtrl,
              builder: (_, __) {
                final p = pageCtrl.hasClients
                    ? ((pageCtrl.page ?? pageCtrl.initialPage.toDouble())
                            .round() +
                        1)
                    : 1;
                return _chip(theme, 'Pg $p/$pageCount');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(ThemeData theme, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.indigoNavySoft.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: AppColors.indigoNavySoft,
        ),
      ),
    );
  }
}

// ── Page-turn trigger editor sheet ────────────────────────────────────────────

class _TurnEditorSheet extends ConsumerStatefulWidget {
  final int folderId;
  final List<ScorePage> pages;
  const _TurnEditorSheet({required this.folderId, required this.pages});

  @override
  ConsumerState<_TurnEditorSheet> createState() => _TurnEditorSheetState();
}

class _TurnEditorSheetState extends ConsumerState<_TurnEditorSheet> {
  final _measureCtrl = TextEditingController();
  int _targetPage = 0;

  @override
  void dispose() {
    _measureCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final turns = ref.watch(scoreTurnsProvider(widget.folderId));

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Auto Page Turns',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'While the metronome plays, the canvas advances to the target '
                'page the moment the measure counter reaches each trigger.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 8),
            // Existing triggers
            Flexible(
              child: turns.when(
                loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
                data: (list) => ListView(
                  shrinkWrap: true,
                  children: list
                      .map((t) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.bolt, size: 20),
                            title: Text(
                                'Measure ${t.measure} → Page ${t.pageIndex + 1}'
                                '${t.pageIndex < widget.pages.length ? ' (${widget.pages[t.pageIndex].name})' : ''}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () => ref
                                  .read(scoreRepositoryProvider)
                                  .deleteTurn(t.id),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
            const Divider(height: 1),
            // Add trigger row
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _measureCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Measure',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.arrow_forward, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _targetPage,
                      isDense: true,
                      decoration: const InputDecoration(
                        labelText: 'Page',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (var i = 0; i < widget.pages.length; i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text(
                              '${i + 1} · ${widget.pages[i].name}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) =>
                          setState(() => _targetPage = v ?? 0),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.indigoNavy,
                        foregroundColor: Colors.white),
                    onPressed: () async {
                      final m = int.tryParse(_measureCtrl.text);
                      if (m == null || m < 1) return;
                      await ref
                          .read(scoreRepositoryProvider)
                          .addTurn(widget.folderId, m, _targetPage);
                      _measureCtrl.clear();
                    },
                    child: const Text('Add'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
