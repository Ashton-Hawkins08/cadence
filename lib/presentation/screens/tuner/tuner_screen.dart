import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/domain/services/analysis/mic_analysis_service.dart';
import 'package:cadence/domain/services/analysis/pitch_analyzer.dart';
import 'package:cadence/presentation/providers/tuner_provider.dart';

// ── Chromatic tuner ───────────────────────────────────────────────────────────
//
// Hosted as the second tab of the Metronome | Tuner pager (no AppBar of its
// own). YIN pitch detection runs in a worker isolate; this screen renders
// note + cents needle. The mic starts only on explicit user action and stops
// when the screen is disposed (autoDispose provider kills the isolate).
//
// The Tempo Ear (BPM listening) lives on the standard metronome page — see
// tempo_ear_sheet.dart.

class TunerScreen extends ConsumerStatefulWidget {
  const TunerScreen({super.key});

  @override
  ConsumerState<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends ConsumerState<TunerScreen>
    with AutomaticKeepAliveClientMixin {
  bool _running = false;

  // Keep mic state alive while swiping between the Metronome and Tuner tabs.
  @override
  bool get wantKeepAlive => true;

  // Captured once — post-await callbacks must never touch `ref` (throws
  // "Cannot use ref after the widget was disposed" if the tab is gone).
  late final MicAnalysisService _service;

  @override
  void initState() {
    super.initState();
    _service = ref.read(micAnalysisServiceProvider);
  }

  Future<void> _toggleMic() async {
    if (_running) {
      await _service.stop();
      if (mounted) setState(() => _running = false);
    } else {
      await _service.start(AnalysisMode.pitch);
      if (mounted) {
        setState(() => _running = _service.state == MicState.running);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _TunerView(service: _service, isDark: isDark)),
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
                        color:
                            (_running ? AppColors.error : AppColors.indigoNavy)
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

// ── Mic problem / idle card ───────────────────────────────────────────────────

class MicProblemCard extends StatelessWidget {
  final MicState state;
  final bool isDark;
  final String idleHint;
  const MicProblemCard({
    super.key,
    required this.state,
    required this.isDark,
    this.idleHint = 'Tap the mic button below to start listening.',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final msg = switch (state) {
      MicState.denied =>
        'Microphone permission denied.\nAllow mic access in system settings to use this tool.',
      MicState.unsupported =>
        'Live microphone streaming isn\'t available on this device.',
      _ => idleHint,
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state == MicState.idle)
              TuningForkIcon(size: 44, color: secondary)
            else
              Icon(Icons.mic_off, size: 44, color: secondary),
            const SizedBox(height: 12),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
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
          return MicProblemCard(state: mic, isDark: isDark);
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
      ..color =
          isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    for (var c = -50; c <= 50; c += 10) {
      final a = pi + (c + 50) / 100 * pi;
      final outer = center + Offset(cos(a), sin(a)) * radius;
      final inner =
          center + Offset(cos(a), sin(a)) * (radius - (c == 0 ? 18 : 10));
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

// ── Bespoke tuning-fork icon ──────────────────────────────────────────────────

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
    canvas.drawLine(Offset(w * 0.38, h * 0.92), Offset(w * 0.62, h * 0.92), p);
  }

  @override
  bool shouldRepaint(_TuningForkPainter old) => old.color != color;
}
