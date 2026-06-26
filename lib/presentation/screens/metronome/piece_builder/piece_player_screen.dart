import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/core/constants/metronome_constants.dart';
import 'package:cadence/data/database/app_database.dart';
import 'package:cadence/presentation/providers/metronome_provider.dart';
import 'package:cadence/presentation/providers/piece_provider.dart';

class PiecePlayerScreen extends ConsumerStatefulWidget {
  final int pieceId;
  final String title;

  const PiecePlayerScreen(
      {super.key, required this.pieceId, required this.title});

  @override
  ConsumerState<PiecePlayerScreen> createState() => _PiecePlayerScreenState();
}

class _PiecePlayerScreenState extends ConsumerState<PiecePlayerScreen>
    with SingleTickerProviderStateMixin {
  List<SectionConfig>? _configs;
  int _activeSectionIndex = 0;
  bool _complete = false;

  late AnimationController _flashCtrl;
  late Animation<double> _flashAnim;
  StreamSubscription<MetronomeState>? _stateSub;
  int _lastVisualBeat = -1;

  @override
  void initState() {
    super.initState();
    _flashCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 90));
    _flashAnim = Tween<double>(begin: 1.0, end: 1.55).animate(
        CurvedAnimation(parent: _flashCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _flashCtrl.dispose();
    ref.read(metronomeEngineProvider).stop();
    super.dispose();
  }

  void _buildConfigsAndPlay(List<PieceSection> sections) {
    if (sections.isEmpty) return;
    _configs = sections.map((s) {
      return SectionConfig(
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
      );
    }).toList();

    final engine = ref.read(metronomeEngineProvider);
    engine.onSectionChanged = (idx) =>
        setState(() => _activeSectionIndex = idx);
    engine.onPieceComplete = () => setState(() => _complete = true);
    engine.start(sections: _configs);

    _stateSub?.cancel();
    _stateSub = engine.stateStream.listen((s) {
      setState(() => _activeSectionIndex = engine.currentSectionIndex);
      if (s.lastFiredLevel != null && s.visualBeatIndex != _lastVisualBeat) {
        _lastVisualBeat = s.visualBeatIndex;
        _flashCtrl.forward(from: 0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sectionsAsync = ref.watch(pieceSectionsProvider(widget.pieceId));
    final stateAsync = ref.watch(metronomeStateProvider);

    return sectionsAsync.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (sections) {
        if (_configs == null && sections.isNotEmpty) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _buildConfigsAndPlay(sections));
        }
        return Scaffold(
          backgroundColor:
              isDark ? AppColors.darkBackground : AppColors.lightBackground,
          appBar: AppBar(
            backgroundColor:
                isDark ? AppColors.darkSurface : AppColors.lightSurface,
            elevation: 0,
            title: Text(widget.title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                ref.read(metronomeEngineProvider).stop();
                Navigator.of(context).pop();
              },
            ),
          ),
          body: stateAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (state) => _buildPlayer(
                context, theme, isDark, state, sections),
          ),
        );
      },
    );
  }

  Widget _buildPlayer(BuildContext context, ThemeData theme, bool isDark,
      MetronomeState state, List<PieceSection> sections) {
    final engine = ref.read(metronomeEngineProvider);

    return SafeArea(
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_complete) _CompleteBanner(theme: theme),

            // ── Live display ────────────────────────────────────────────
            _LiveDisplay(
              state: state,
              sections: sections,
              activeSectionIndex: _activeSectionIndex,
              isDark: isDark,
              theme: theme,
            ),

            const SizedBox(height: 24),

            // ── Visual timeline ─────────────────────────────────────────
            Text('Sections',
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            _VisualTimeline(
              sections: sections,
              activeSectionIndex: _activeSectionIndex,
              isDark: isDark,
              theme: theme,
            ),

            const SizedBox(height: 28),

            // ── Beat indicator (visual beats only) ──────────────────────
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: List.generate(
                    state.visualTotalBeats.clamp(1, 16), (i) {
                  final isActive =
                      state.isPlaying && i == state.visualBeatIndex;
                  return AnimatedBuilder(
                    animation: _flashAnim,
                    builder: (_, __) {
                      final scale = isActive ? _flashAnim.value : 1.0;
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: i == 0 ? 20 : 16,
                          height: i == 0 ? 20 : 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActive
                                ? (i == 0
                                    ? AppColors.indigoNavy
                                    : AppColors.indigoNavySoft)
                                : (isDark
                                    ? AppColors.darkDivider
                                    : AppColors.lightDivider),
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ),

            const SizedBox(height: 28),

            // ── Transport ───────────────────────────────────────────────
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.stop_circle_outlined),
                    iconSize: 48,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    onPressed: () {
                      engine.stop();
                      setState(() {
                        _activeSectionIndex = 0;
                        _complete = false;
                        _lastVisualBeat = -1;
                      });
                    },
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () {
                      if (_complete) {
                        setState(() {
                          _activeSectionIndex = 0;
                          _complete = false;
                          _lastVisualBeat = -1;
                        });
                        if (_configs != null) {
                          engine.start(sections: _configs);
                        }
                      } else if (!state.isPlaying && !state.isPaused) {
                        if (_configs != null) {
                          engine.start(sections: _configs);
                        }
                      } else if (state.isPlaying && !state.isPaused) {
                        engine.pause();
                      } else {
                        engine.resume();
                      }
                    },
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.indigoNavy,
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.indigoNavy.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        _complete
                            ? Icons.replay
                            : (state.isPlaying && !state.isPaused)
                                ? Icons.pause
                                : Icons.play_arrow,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Live display card ─────────────────────────────────────────────────────────

class _LiveDisplay extends StatelessWidget {
  final MetronomeState state;
  final List<PieceSection> sections;
  final int activeSectionIndex;
  final bool isDark;
  final ThemeData theme;

  const _LiveDisplay({
    required this.state,
    required this.sections,
    required this.activeSectionIndex,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final active = activeSectionIndex < sections.length
        ? sections[activeSectionIndex]
        : null;
    final measuresRemaining = active != null
        ? (active.endMeasure - state.currentMeasure + 1).clamp(0, 9999)
        : 0;
    final ts = active != null
        ? MetronomeTimeSignature.values.firstWhere(
            (v) => v.name == active.timeSignature,
            orElse: () => MetronomeTimeSignature.sig4_4)
        : state.timeSignature;

    return Card(
      color: AppColors.indigoNavy,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Stat(label: 'BPM', value: '${state.bpm}'),
                _Stat(label: 'Time Sig', value: ts.display),
                _Stat(label: 'Measure', value: 'M${state.currentMeasure}'),
                _Stat(
                    label: 'Section',
                    value:
                        '${activeSectionIndex + 1}/${sections.length}'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '$measuresRemaining measure${measuresRemaining == 1 ? '' : 's'} remaining in section',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.white70, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style:
                  const TextStyle(color: Colors.white60, fontSize: 10)),
        ],
      );
}

// ── Visual timeline ───────────────────────────────────────────────────────────

class _VisualTimeline extends StatelessWidget {
  final List<PieceSection> sections;
  final int activeSectionIndex;
  final bool isDark;
  final ThemeData theme;

  const _VisualTimeline({
    required this.sections,
    required this.activeSectionIndex,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) return const SizedBox.shrink();
    final totalMeasures =
        sections.last.endMeasure - sections.first.startMeasure + 1;
    if (totalMeasures <= 0) return const SizedBox.shrink();

    return SizedBox(
      height: 52,
      child: LayoutBuilder(builder: (context, constraints) {
        final total = constraints.maxWidth;
        return Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            ...sections.asMap().entries.map((e) {
              final i = e.key;
              final s = e.value;
              final start = s.startMeasure - sections.first.startMeasure;
              final length = s.endMeasure - s.startMeasure + 1;
              final x = (start / totalMeasures) * total;
              final w = ((length / totalMeasures) * total).clamp(2.0, total);
              final isActive = i == activeSectionIndex;
              return Positioned(
                left: x,
                width: w,
                top: 0,
                bottom: 0,
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.indigoNavySoft
                        : AppColors.indigoNavy.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                    border: isActive
                        ? Border.all(color: AppColors.indigoNavy, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: Text('${i + 1}',
                        style: TextStyle(
                            color: isActive ? Colors.white : Colors.white60,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              );
            }),
          ],
        );
      }),
    );
  }
}

// ── Complete banner ───────────────────────────────────────────────────────────

class _CompleteBanner extends StatelessWidget {
  final ThemeData theme;
  const _CompleteBanner({required this.theme});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline,
                color: AppColors.success, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Piece complete! Tap play to restart.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppColors.success)),
            ),
          ],
        ),
      );
}
