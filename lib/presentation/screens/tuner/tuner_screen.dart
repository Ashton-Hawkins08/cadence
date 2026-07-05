import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/domain/services/analysis/mic_analysis_service.dart';
import 'package:cadence/domain/services/analysis/pitch_analyzer.dart';
import 'package:cadence/domain/services/analysis/tempo_analyzer.dart';
import 'package:cadence/presentation/providers/tuner_provider.dart';

// ── Tuner / Tempo listening screen ────────────────────────────────────────────
//
// Two mic-driven tools behind one destination:
//   • Chromatic tuner — YIN pitch → note + cents deviation on an arc gauge
//   • Tempo listener  — onset detection → live BPM + stability meter
//
// The mic starts only on explicit user action and stops on leave
// (autoDispose provider kills the isolate + stream).

enum _TunerTab { tuner, tempo }

class TunerScreen extends ConsumerStatefulWidget {
  const TunerScreen({super.key});

  @override
  ConsumerState<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends ConsumerState<TunerScreen> {
  _TunerTab _tab = _TunerTab.tuner;
  bool _running = false;

  MicAnalysisService get _service => ref.read(micAnalysisServiceProvider);

  Future<void> _toggleMic() async {
    if (_running) {
      await _service.stop();
      if (mounted) setState(() => _running = false);
    } else {
      await _service.start(
          _tab == _TunerTab.tuner ? AnalysisMode.pitch : AnalysisMode.tempo);
      if (mounted) {
        setState(() => _running = _service.state == MicState.running);
      }
    }
  }

  Future<void> _switchTab(_TunerTab tab) async {
    if (tab == _tab) return;
    final wasRunning = _running;
    if (wasRunning) await _service.stop();
    setState(() {
      _tab = tab;
      _running = false;
    });
    if (wasRunning) await _toggleMic(); // seamless mode hand-off
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(_tab == _TunerTab.tuner ? 'Chromatic Tuner' : 'Tempo Ear',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        centerTitle: true,
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            // ── Mode segments ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _SegmentChip(
                    label: 'Tuner',
                    icon: Icons.graphic_eq,
                    selected: _tab == _TunerTab.tuner,
                    onTap: () => _switchTab(_TunerTab.tuner),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _SegmentChip(
                    label: 'Tempo',
                    icon: Icons.hearing,
                    selected: _tab == _TunerTab.tempo,
                    onTap: () => _switchTab(_TunerTab.tempo),
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _tab == _TunerTab.tuner
                  ? _TunerView(service: _service, isDark: isDark)
                  : _TempoView(service: _service, isDark: isDark),
            ),
            // ── Mic control ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: GestureDetector(
                onTap: _toggleMic,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _running ? AppColors.error : AppColors.indigoNavy,
                    boxShadow: [
                      BoxShadow(
                        color: (_running
                                ? AppColors.error
                                : AppColors.indigoNavy)
                            .withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _running ? Icons.mic_off : Icons.mic,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Segment chip ──────────────────────────────────────────────────────────────

class _SegmentChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;

  const _SegmentChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.indigoNavySoft
                : (isDark ? AppColors.darkCard : AppColors.lightCard),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected
                      ? Colors.white
                      : (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary)),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white
                      : (isDark ? AppColors.darkText : AppColors.lightText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mic problem card ──────────────────────────────────────────────────────────

class _MicProblem extends StatelessWidget {
  final MicState state;
  final bool isDark;
  const _MicProblem({required this.state, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final msg = switch (state) {
      MicState.denied =>
        'Microphone permission denied.\nAllow mic access in system settings to use this tool.',
      MicState.unsupported =>
        'Live microphone streaming isn\'t available on this device.',
      _ => 'Tap the mic button below to start listening.',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              state == MicState.idle ? Icons.mic_none : Icons.mic_off,
              size: 44,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tuner view ────────────────────────────────────────────────────────────────

class _TunerView extends StatelessWidget {
  final MicAnalysisService service;
  final bool isDark;
  const _TunerView({required this.service, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<MicState>(
      stream: service.stateStream,
      initialData: service.state,
      builder: (_, micSnap) {
        final mic = micSnap.data ?? MicState.idle;
        if (mic != MicState.running) {
          return _MicProblem(state: mic, isDark: isDark);
        }
        return StreamBuilder<NoteReading?>(
          stream: service.noteStream,
          builder: (_, snap) {
            final note = snap.data;
            final cents = note?.cents ?? 0.0;
            final inTune = note != null && cents.abs() <= 5;

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Needle gauge (−50…+50 cents)
                SizedBox(
                  width: 280,
                  height: 150,
                  child: CustomPaint(
                    painter: _CentsGaugePainter(
                      cents: note == null ? null : cents,
                      isDark: isDark,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Note name + octave
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      note?.name ?? '—',
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontSize: 88,
                        fontWeight: FontWeight.w800,
                        color: inTune
                            ? AppColors.success
                            : (isDark
                                ? AppColors.darkText
                                : AppColors.indigoNavy),
                      ),
                    ),
                    if (note != null)
                      Text(
                        '${note.octave}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  note == null
                      ? 'Listening…'
                      : '${note.frequency.toStringAsFixed(1)} Hz   ·   '
                          '${cents >= 0 ? '+' : ''}${cents.toStringAsFixed(0)}¢',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    fontWeight: FontWeight.w600,
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

// Arc gauge: −50¢ … +50¢ with a needle. Green zone at ±5¢.
class _CentsGaugePainter extends CustomPainter {
  final double? cents;
  final bool isDark;
  _CentsGaugePainter({required this.cents, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.95);
    final radius = size.height * 0.85;
    // 180° sweep: −50¢ = 180°(left), +50¢ = 0°(right); angles in radians.
    const startAngle = pi;
    const sweep = pi;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = isDark ? AppColors.darkDivider : AppColors.lightDivider;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        startAngle, sweep, false, track);

    // In-tune green zone: ±5¢ around the top of the arc.
    final zone = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = AppColors.success.withValues(alpha: 0.8);
    const zoneHalf = 5 / 50 * (pi / 2); // 5¢ in radians
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        pi * 1.5 - zoneHalf, zoneHalf * 2, false, zone);

    // Ticks every 10¢
    final tick = Paint()
      ..strokeWidth = 2
      ..color = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    for (var c = -50; c <= 50; c += 10) {
      final a = pi + (c + 50) / 100 * pi;
      final outer = center + Offset(cos(a), sin(a)) * radius;
      final inner = center + Offset(cos(a), sin(a)) * (radius - (c == 0 ? 18 : 10));
      canvas.drawLine(inner, outer, tick);
    }

    // Needle
    if (cents != null) {
      final clamped = cents!.clamp(-50.0, 50.0);
      final a = pi + (clamped + 50) / 100 * pi;
      final needleColor = clamped.abs() <= 5
          ? AppColors.success
          : clamped.abs() <= 15
              ? AppColors.warning
              : AppColors.error;
      final needle = Paint()
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = needleColor;
      canvas.drawLine(
          center, center + Offset(cos(a), sin(a)) * (radius - 24), needle);
      canvas.drawCircle(center, 7, Paint()..color = needleColor);
    }
  }

  @override
  bool shouldRepaint(_CentsGaugePainter old) =>
      old.cents != cents || old.isDark != isDark;
}

// ── Tempo view ────────────────────────────────────────────────────────────────

class _TempoView extends StatelessWidget {
  final MicAnalysisService service;
  final bool isDark;
  const _TempoView({required this.service, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<MicState>(
      stream: service.stateStream,
      initialData: service.state,
      builder: (_, micSnap) {
        final mic = micSnap.data ?? MicState.idle;
        if (mic != MicState.running) {
          return _MicProblem(state: mic, isDark: isDark);
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
                    fontSize: 96,
                    fontWeight: FontWeight.w800,
                    color:
                        isDark ? AppColors.darkText : AppColors.indigoNavy,
                  ),
                ),
                Text(
                  locked ? 'BPM' : 'Play steady beats…',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 28),
                // Stability meter
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

// ── Bespoke tuning-fork icon (for the metronome shell nav) ────────────────────

class TuningForkIcon extends StatelessWidget {
  final double size;
  final Color color;
  const TuningForkIcon({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _TuningForkPainter(color),
    );
  }
}

class _TuningForkPainter extends CustomPainter {
  final Color color;
  _TuningForkPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.11
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;

    // Two prongs joined into a stem — the classic fork silhouette.
    final path = Path()
      // left prong
      ..moveTo(w * 0.30, h * 0.08)
      ..lineTo(w * 0.30, h * 0.42)
      ..quadraticBezierTo(w * 0.30, h * 0.56, w * 0.50, h * 0.56)
      // right prong
      ..moveTo(w * 0.70, h * 0.08)
      ..lineTo(w * 0.70, h * 0.42)
      ..quadraticBezierTo(w * 0.70, h * 0.56, w * 0.50, h * 0.56)
      // stem
      ..moveTo(w * 0.50, h * 0.56)
      ..lineTo(w * 0.50, h * 0.86);
    canvas.drawPath(path, p);
    // base foot
    canvas.drawLine(
        Offset(w * 0.38, h * 0.92), Offset(w * 0.62, h * 0.92), p);
  }

  @override
  bool shouldRepaint(_TuningForkPainter old) => old.color != color;
}
