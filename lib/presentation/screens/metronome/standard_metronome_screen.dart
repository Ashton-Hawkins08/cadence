import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/core/constants/app_constants.dart';
import 'package:cadence/core/constants/metronome_constants.dart';
import 'package:cadence/presentation/providers/metronome_provider.dart';

class StandardMetronomeScreen extends ConsumerStatefulWidget {
  const StandardMetronomeScreen({super.key});

  @override
  ConsumerState<StandardMetronomeScreen> createState() =>
      _StandardMetronomeScreenState();
}

class _StandardMetronomeScreenState
    extends ConsumerState<StandardMetronomeScreen>
    with SingleTickerProviderStateMixin {
  final _bpmController = TextEditingController();
  final _bpmFocus = FocusNode();
  bool _editingBpm = false;

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
    // Reset _editingBpm when focus leaves the field (e.g. back-button dismiss).
    _bpmFocus.addListener(() {
      if (!_bpmFocus.hasFocus && _editingBpm) {
        setState(() => _editingBpm = false);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _listenFlash());
  }

  void _listenFlash() {
    final engine = ref.read(metronomeEngineProvider);
    _stateSub = engine.stateStream.listen((s) {
      if (s.lastFiredLevel != null && s.visualBeatIndex != _lastVisualBeat) {
        _lastVisualBeat = s.visualBeatIndex;
        _flashCtrl.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _bpmController.dispose();
    _bpmFocus.dispose();
    _flashCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final engine = ref.read(metronomeEngineProvider);
    final stateAsync = ref.watch(metronomeStateProvider);

    return stateAsync.when(
      loading: () => const _LoadingShell(),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (state) => _buildBody(context, theme, isDark, engine, state),
    );
  }

  Widget _buildBody(BuildContext context, ThemeData theme, bool isDark,
      MetronomeEngine engine, MetronomeState state) {
    if (!_editingBpm) _bpmController.text = state.bpm.toString();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Metronome',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        centerTitle: true,
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
      ),
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),

              // ── BPM display ─────────────────────────────────────────────
              Center(
                child: SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _bpmController,
                    focusNode: _bpmFocus,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.indigoNavy,
                      fontSize: 64,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      filled: false,
                      suffixText: 'BPM',
                      suffixStyle: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onTap: () => setState(() => _editingBpm = true),
                    onSubmitted: (v) {
                      setState(() => _editingBpm = false);
                      final parsed = int.tryParse(v);
                      if (parsed != null) {
                        engine.setBpm(parsed.clamp(
                            AppConstants.minBpm, AppConstants.maxBpm));
                      }
                    },
                  ),
                ),
              ),

              // ── BPM Slider ──────────────────────────────────────────────
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.indigoNavySoft,
                  inactiveTrackColor:
                      isDark ? AppColors.darkDivider : AppColors.lightDivider,
                  thumbColor: AppColors.indigoNavy,
                  overlayColor: AppColors.indigoNavySoft.withValues(alpha: 0.2),
                  trackHeight: 4,
                ),
                child: Slider(
                  min: AppConstants.minBpm.toDouble(),
                  max: AppConstants.maxBpm.toDouble(),
                  value: state.bpm
                      .clamp(AppConstants.minBpm, AppConstants.maxBpm)
                      .toDouble(),
                  onChanged: (v) => engine.setBpm(v.round()),
                ),
              ),

              // ── Tap Tempo ───────────────────────────────────────────────
              OutlinedButton.icon(
                onPressed: engine.tapTempo,
                icon: const Icon(Icons.touch_app, size: 18),
                label: const Text('Tap Tempo'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: isDark
                          ? AppColors.darkDivider
                          : AppColors.lightDivider),
                ),
              ),

              const SizedBox(height: 20),

              // ── Time Signature ──────────────────────────────────────────
              _SectionLabel(label: 'Time Signature', theme: theme),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: MetronomeTimeSignature.values.map((ts) {
                  final sel = ts == state.timeSignature;
                  return ChoiceChip(
                    label: Text(ts.display),
                    selected: sel,
                    onSelected: (_) => engine.setTimeSignature(ts),
                    selectedColor: AppColors.indigoNavySoft,
                    backgroundColor:
                        isDark ? AppColors.darkCard : AppColors.lightCard,
                    labelStyle: theme.textTheme.labelSmall?.copyWith(
                      color: sel
                          ? Colors.white
                          : (isDark ? AppColors.darkText : AppColors.lightText),
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // ── Subdivision ─────────────────────────────────────────────
              _SectionLabel(label: 'Subdivision', theme: theme),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: state.timeSignature.availableSubdivisions.map((sub) {
                  final sel = sub == state.subdivision;
                  return ChoiceChip(
                    label: Text(sub.displayName),
                    selected: sel,
                    onSelected: (_) => engine.setSubdivision(sub),
                    selectedColor: AppColors.indigoNavySoft,
                    backgroundColor:
                        isDark ? AppColors.darkCard : AppColors.lightCard,
                    labelStyle: theme.textTheme.labelSmall?.copyWith(
                      color: sel
                          ? Colors.white
                          : (isDark ? AppColors.darkText : AppColors.lightText),
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // ── Accent first beat ───────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Accent First Beat',
                      style: theme.textTheme.bodyMedium),
                  Switch(
                    value: state.accentFirstBeat,
                    onChanged: engine.setAccentFirstBeat,
                    activeColor: AppColors.indigoNavySoft,
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ── Visual beat indicator (always shows DEFAULT beat count) ─
              _BeatIndicator(
                state: state,
                flashAnim: _flashAnim,
                isDark: isDark,
              ),

              const SizedBox(height: 28),

              // ── Transport ───────────────────────────────────────────────
              _TransportRow(state: state, engine: engine, isDark: isDark),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Beat indicator — dots = visual beats from default subdivision ─────────────

class _BeatIndicator extends StatelessWidget {
  final MetronomeState state;
  final Animation<double> flashAnim;
  final bool isDark;

  const _BeatIndicator({
    required this.state,
    required this.flashAnim,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final total = state.visualTotalBeats.clamp(1, 16);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: List.generate(total, (i) {
        final isActive = state.isPlaying && i == state.visualBeatIndex;
        final isDownbeat = i == 0;
        return AnimatedBuilder(
          animation: flashAnim,
          builder: (_, __) {
            final scale = isActive ? flashAnim.value : 1.0;
            return Transform.scale(
              scale: scale,
              child: Container(
                width: isDownbeat ? 20 : 16,
                height: isDownbeat ? 20 : 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? (isDownbeat
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
    );
  }
}

// ── Transport row ─────────────────────────────────────────────────────────────

class _TransportRow extends StatelessWidget {
  final MetronomeState state;
  final MetronomeEngine engine;
  final bool isDark;

  const _TransportRow(
      {required this.state, required this.engine, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (state.isPlaying || state.isPaused) ...[
          IconButton(
            onPressed: engine.stop,
            icon: const Icon(Icons.stop_circle_outlined),
            iconSize: 48,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
          const SizedBox(width: 16),
        ],
        GestureDetector(
          onTap: () {
            if (!state.isPlaying && !state.isPaused) {
              engine.start();
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
                  color: AppColors.indigoNavy.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              (state.isPlaying && !state.isPaused)
                  ? Icons.pause
                  : Icons.play_arrow,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final ThemeData theme;
  const _SectionLabel({required this.label, required this.theme});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Text(label,
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w600)),
      );
}

class _LoadingShell extends StatelessWidget {
  const _LoadingShell();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Initializing audio…',
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      );
}
