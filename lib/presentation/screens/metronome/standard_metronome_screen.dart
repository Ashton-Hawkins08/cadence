import 'dart:async';
import 'package:flutter/cupertino.dart' show CupertinoTimerPicker, CupertinoTimerPickerMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/core/constants/app_constants.dart';
import 'package:cadence/core/constants/metronome_constants.dart';
import 'package:cadence/presentation/providers/metronome_provider.dart';
import 'package:cadence/presentation/providers/randomizer_provider.dart';
import 'package:cadence/presentation/providers/cognitive_break_provider.dart';
import 'tempo_ear_sheet.dart';

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
    final rand = ref.watch(randomizerProvider);

    if (!_editingBpm) {
      final s = state.bpm.toString();
      if (_bpmController.text != s) _bpmController.text = s;
    }

    // No AppBar here — this screen is hosted inside the Metronome | Tuner
    // tab pager (metronome_tuner_screen.dart), which owns the header.
    return Scaffold(
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
              // Hidden entirely while the blind randomizer is active: the
              // field, the slider, and tap tempo would all leak the secret
              // tempo (or overwrite it).
              if (!rand.enabled) ...[
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

                // ── BPM Slider ────────────────────────────────────────────
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.indigoNavySoft,
                    inactiveTrackColor:
                        isDark ? AppColors.darkDivider : AppColors.lightDivider,
                    thumbColor: AppColors.indigoNavy,
                    overlayColor:
                        AppColors.indigoNavySoft.withValues(alpha: 0.2),
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

                // ── Tap Tempo ─────────────────────────────────────────────
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
              ] else ...[
                _HiddenBpmBlock(
                  revealed: rand.revealed,
                  bpm: state.bpm,
                  isDark: isDark,
                  onTap: () => ref.read(randomizerProvider.notifier).reveal(),
                ),
                const SizedBox(height: 12),
                _RandomizerControls(
                    baseBpm: rand.baseBpm, range: rand.range, isDark: isDark),
              ],

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

              const SizedBox(height: 20),

              // ── Training modes ──────────────────────────────────────────
              _SectionLabel(label: 'Training', theme: theme),
              const SizedBox(height: 8),
              _RandomizerToggleCard(isDark: isDark),
              const SizedBox(height: 8),
              _CognitiveBreakCard(state: state, isDark: isDark),
              const SizedBox(height: 8),
              _TempoEarCard(isDark: isDark),

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

// ── Blind randomizer: hidden BPM block ────────────────────────────────────────
//
// While hidden this is a solid near-black container — deliberately unreadable,
// per the training design: the musician must deduce the tempo by ear. One tap
// reveals the number in place.

class _HiddenBpmBlock extends StatelessWidget {
  final bool revealed;
  final int bpm;
  final bool isDark;
  final VoidCallback onTap;

  const _HiddenBpmBlock({
    required this.revealed,
    required this.bpm,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: revealed ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        height: 112,
        width: double.infinity,
        decoration: BoxDecoration(
          color: revealed
              ? (isDark ? AppColors.darkCard : AppColors.lightCard)
              : const Color(0xFF0A0A14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.streakGold.withValues(alpha: 0.85),
            width: 1.5,
          ),
        ),
        child: Center(
          child: revealed
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$bpm',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 56,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.indigoNavy,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'BPM',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.streakGold,
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.visibility_off,
                        color: Colors.white38, size: 30),
                    const SizedBox(height: 6),
                    Text(
                      'TAP TO REVEAL',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white54,
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Blind randomizer: base/range chip + re-roll button ────────────────────────

class _RandomizerControls extends ConsumerWidget {
  final int baseBpm;
  final int range;
  final bool isDark;

  const _RandomizerControls({
    required this.baseBpm,
    required this.range,
    required this.isDark,
  });

  Future<void> _editWindow(BuildContext context, WidgetRef ref) async {
    final baseCtrl = TextEditingController(text: '$baseBpm');
    final rangeCtrl = TextEditingController(text: '$range');
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Randomizer Window'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: baseCtrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Base BPM',
                  hintText: '1 – 300',
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null ||
                      n < AppConstants.minBpm ||
                      n > AppConstants.maxBpm) {
                    return 'Between ${AppConstants.minBpm} and ${AppConstants.maxBpm}';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: rangeCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Range (±)',
                  hintText: 'e.g. 40 → base 120 rolls 80–160',
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 1 || n >= AppConstants.maxBpm) {
                    return 'Between 1 and ${AppConstants.maxBpm - 1}';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Text(
                'The window always stays inside 1–${AppConstants.maxBpm} BPM.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Apply')),
        ],
      ),
    );

    if (ok == true) {
      ref.read(randomizerProvider.notifier).configure(
            baseBpm: int.parse(baseCtrl.text),
            range: int.parse(rangeCtrl.text),
          );
    }
    baseCtrl.dispose();
    rangeCtrl.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Tappable: correct the base or widen/narrow the roll window.
        GestureDetector(
          onTap: () => _editWindow(context, ref),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.indigoNavySoft.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Base $baseBpm  ±$range',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 4),
                Icon(Icons.edit, size: 13, color: AppColors.indigoNavySoft),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: () =>
              ref.read(randomizerProvider.notifier).randomizeAgain(),
          icon: const Icon(Icons.casino, size: 18),
          label: const Text('Randomize Again'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.indigoNavy,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

// ── Blind randomizer: on/off card ─────────────────────────────────────────────

class _RandomizerToggleCard extends ConsumerWidget {
  final bool isDark;
  const _RandomizerToggleCard({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rand = ref.watch(randomizerProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.casino_outlined,
              size: 20, color: AppColors.indigoNavySoft),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Blind BPM Randomizer',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  'Hidden tempo within ±${rand.range} of your base',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: rand.enabled,
            activeColor: AppColors.indigoNavySoft,
            onChanged: (on) {
              final ctrl = ref.read(randomizerProvider.notifier);
              on ? ctrl.enable() : ctrl.disable();
            },
          ),
        ],
      ),
    );
  }
}

// ── Tempo Ear card ────────────────────────────────────────────────────────────

class _TempoEarCard extends StatelessWidget {
  final bool isDark;
  const _TempoEarCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => showTempoEarSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.hearing, size: 20, color: AppColors.indigoNavySoft),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tempo Ear',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  Text(
                    'Hear a tempo, get its BPM — odd meters included',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 20,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary),
          ],
        ),
      ),
    );
  }
}

// ── Cognitive break card ──────────────────────────────────────────────────────
//
// Toggle + duration wheel. The engine owns the actual break; this card just
// arms it and shows the live countdown while it runs.

class _CognitiveBreakCard extends ConsumerStatefulWidget {
  final MetronomeState state;
  final bool isDark;
  const _CognitiveBreakCard({required this.state, required this.isDark});

  @override
  ConsumerState<_CognitiveBreakCard> createState() =>
      _CognitiveBreakCardState();
}

class _CognitiveBreakCardState extends ConsumerState<_CognitiveBreakCard> {
  Timer? _countdownTicker;

  @override
  void dispose() {
    _countdownTicker?.cancel();
    super.dispose();
  }

  void _syncTicker(bool active) {
    if (active && _countdownTicker == null) {
      _countdownTicker = Timer.periodic(
          const Duration(milliseconds: 500), (_) => setState(() {}));
    } else if (!active && _countdownTicker != null) {
      _countdownTicker?.cancel();
      _countdownTicker = null;
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDuration() async {
    final current = ref.read(cognitiveBreakDurationProvider);
    var picked = current;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor:
          widget.isDark ? AppColors.darkCard : AppColors.lightCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Text('Break Duration',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      // Enforce a sane floor — a 3-second "break" is a tap
                      // slip, not a training phase.
                      if (picked < const Duration(seconds: 15)) {
                        picked = const Duration(seconds: 15);
                      }
                      ref
                          .read(cognitiveBreakDurationProvider.notifier)
                          .state = picked;
                      Navigator.pop(ctx);
                    },
                    child: const Text('Set'),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 190,
              child: CupertinoTimerPicker(
                mode: CupertinoTimerPickerMode.ms,
                initialTimerDuration: current,
                onTimerDurationChanged: (d) => picked = d,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = widget.isDark;
    final engine = ref.read(metronomeEngineProvider);
    final duration = ref.watch(cognitiveBreakDurationProvider);
    final active = widget.state.cognitiveBreakActive;
    _syncTicker(active);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.psychology_outlined,
              size: 20, color: AppColors.indigoNavySoft),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cognitive Break',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  active
                      ? 'Ends in ${_fmt(engine.cognitiveBreakRemaining)}'
                      : 'Tempo drift ±3 BPM · surprise dropped beats',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: active
                        ? AppColors.indigoNavySoft
                        : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary),
                    fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          // Duration wheel trigger — disabled mid-break (the active phase
          // runs to its dialed-in end; cancel to change it).
          TextButton(
            onPressed: active ? null : _pickDuration,
            child: Text(_fmt(duration)),
          ),
          Switch(
            value: active,
            activeColor: AppColors.indigoNavySoft,
            onChanged: (on) {
              if (on) {
                // The break needs a running clock to attach to.
                if (!widget.state.isPlaying) engine.start();
                engine.startCognitiveBreak(duration);
              } else {
                engine.cancelCognitiveBreak();
              }
            },
          ),
        ],
      ),
    );
  }
}
