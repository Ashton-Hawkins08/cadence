import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/core/constants/metronome_constants.dart';
import 'package:cadence/domain/services/analysis/mic_analysis_service.dart';
import 'package:cadence/domain/services/analysis/tempo_analyzer.dart';
import 'package:cadence/presentation/providers/tuner_provider.dart';
import 'package:cadence/presentation/screens/tuner/tuner_screen.dart'
    show MicProblemCard;

// ── Tempo Ear ─────────────────────────────────────────────────────────────────
//
// BPM listening engine, opened as a bottom sheet from the standard metronome
// page. The user picks the time signature they're playing in; even meters use
// generic even-beat detection, while mixed meters (5/8, 7/8, 11/8) switch the
// analyzer to the unit solver that expects beats of 2 and 3 eighths — see
// tempo_analyzer.dart. Detected BPM is always the quarter-note rate, i.e.
// exactly the number to dial into the metronome at that signature.

/// Eighth-note beat groups per signature for the mixed-meter solver.
/// Empty = evenly spaced beats (generic detection). Only the multiset of
/// group lengths matters — 2+2+3 and 3+2+2 detect identically.
List<int> beatUnitsFor(MetronomeTimeSignature ts) {
  switch (ts) {
    case MetronomeTimeSignature.sig5_8:
      return const [2, 3];
    case MetronomeTimeSignature.sig7_8:
      return const [2, 2, 3];
    case MetronomeTimeSignature.sig11_8:
      return const [3, 3, 3, 2];
    default:
      return const [];
  }
}

Future<void> showTempoEarSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.78,
      child: TempoEarSheet(),
    ),
  );
}

class TempoEarSheet extends ConsumerStatefulWidget {
  const TempoEarSheet({super.key});

  @override
  ConsumerState<TempoEarSheet> createState() => _TempoEarSheetState();
}

class _TempoEarSheetState extends ConsumerState<TempoEarSheet> {
  MetronomeTimeSignature _signature = MetronomeTimeSignature.sig4_4;
  bool _running = false;

  MicAnalysisService get _service => ref.read(micAnalysisServiceProvider);

  @override
  void dispose() {
    // The provider is autoDispose, but the standard screen may still hold it
    // alive — stop the mic explicitly when the sheet closes.
    _service.stop();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    if (_running) {
      await _service.stop();
      if (mounted) setState(() => _running = false);
    } else {
      await _service.start(AnalysisMode.tempo,
          beatUnits: beatUnitsFor(_signature));
      if (mounted) {
        setState(() => _running = _service.state == MicState.running);
      }
    }
  }

  Future<void> _pickSignature(MetronomeTimeSignature ts) async {
    if (ts == _signature) return;
    final wasRunning = _running;
    if (wasRunning) await _service.stop();
    setState(() {
      _signature = ts;
      _running = false;
    });
    if (wasRunning) await _toggleMic(); // restart with the new beat model
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mixed = beatUnitsFor(_signature).isNotEmpty;

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hearing, size: 20),
              const SizedBox(width: 8),
              Text('Tempo Ear',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Play steady beats — Cadence finds your tempo.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 14),

          // ── Time signature: tells the analyzer what beat spacing to expect
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: MetronomeTimeSignature.values.map((ts) {
                final sel = ts == _signature;
                return ChoiceChip(
                  label: Text(ts.display),
                  selected: sel,
                  onSelected: (_) => _pickSignature(ts),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                );
              }).toList(),
            ),
          ),
          if (mixed)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Text(
                'Mixed meter: listening for beats of 2 and 3 eighths. '
                'Play the MAIN beats (group onsets), not every eighth.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.indigoNavySoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          // ── Live reading ─────────────────────────────────────────────────
          Expanded(child: _TempoReadout(service: _service, isDark: isDark)),

          // ── Mic control ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: GestureDetector(
              onTap: _toggleMic,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _running ? AppColors.error : AppColors.indigoNavy,
                  boxShadow: [
                    BoxShadow(
                      color:
                          (_running ? AppColors.error : AppColors.indigoNavy)
                              .withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _running ? Icons.mic_off : Icons.mic,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TempoReadout extends StatelessWidget {
  final MicAnalysisService service;
  final bool isDark;
  const _TempoReadout({required this.service, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<MicState>(
      stream: service.stateStream,
      initialData: service.state,
      builder: (_, micSnap) {
        final mic = micSnap.data ?? MicState.idle;
        if (mic != MicState.running) {
          return MicProblemCard(
            state: mic,
            isDark: isDark,
            idleHint: 'Tap the mic button to start listening.',
          );
        }
        return StreamBuilder<TempoReading>(
          stream: service.tempoStream,
          builder: (_, snap) {
            final r = snap.data ?? TempoReading.none;
            final locked = r.bpm > 0;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  locked ? r.bpm.round().toString() : '· · ·',
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontSize: 84,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkText : AppColors.indigoNavy,
                  ),
                ),
                Text(
                  locked ? 'BPM (♩)' : 'Play steady beats…',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 220,
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: r.stability,
                          minHeight: 8,
                          backgroundColor: isDark
                              ? AppColors.darkDivider
                              : AppColors.lightDivider,
                          valueColor: AlwaysStoppedAnimation(
                            r.stability > 0.75
                                ? AppColors.success
                                : r.stability > 0.4
                                    ? AppColors.warning
                                    : AppColors.error,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Steadiness   ·   ${r.beatCount} beats heard',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
