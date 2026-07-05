import 'package:flutter/material.dart';
import 'package:cadence/domain/models/score_annotation.dart';

// ── Annotation canvas ─────────────────────────────────────────────────────────
//
// Transparent drawing layer stacked over a score page image. All geometry is
// image-normalized (0…1), so the same strokes repaint identically at any
// widget size. Repainting existing strokes is one CustomPaint pass — no
// bitmaps, no decode, no jank on page swipes.
//
// Eraser is stroke-level (vector path eraser): touching any segment of a
// stroke removes the whole stroke, which matches how musicians actually
// clean up a marking.

class AnnotationToolConfig {
  final StrokeTool tool;
  final Color color;

  /// Fraction of page width (normalized, like stroke storage).
  final double width;
  final bool eraser;

  const AnnotationToolConfig({
    this.tool = StrokeTool.pen,
    this.color = const Color(0xFF04006B),
    this.width = 0.004,
    this.eraser = false,
  });

  AnnotationToolConfig copyWith({
    StrokeTool? tool,
    Color? color,
    double? width,
    bool? eraser,
  }) =>
      AnnotationToolConfig(
        tool: tool ?? this.tool,
        color: color ?? this.color,
        width: width ?? this.width,
        eraser: eraser ?? this.eraser,
      );

  double get effectiveOpacity => tool == StrokeTool.highlighter ? 0.35 : 1.0;
  double get effectiveWidth =>
      tool == StrokeTool.highlighter ? width * 4.5 : width;
}

class AnnotationCanvas extends StatefulWidget {
  final List<ScoreStroke> strokes;
  final bool drawEnabled;
  final AnnotationToolConfig config;
  final void Function(List<ScoreStroke> strokes) onChanged;

  const AnnotationCanvas({
    super.key,
    required this.strokes,
    required this.drawEnabled,
    required this.config,
    required this.onChanged,
  });

  @override
  State<AnnotationCanvas> createState() => _AnnotationCanvasState();
}

class _AnnotationCanvasState extends State<AnnotationCanvas> {
  List<double>? _inProgress; // normalized points of the stroke being drawn

  Offset _normalize(Offset local, Size size) => Offset(
        (local.dx / size.width).clamp(0.0, 1.0),
        (local.dy / size.height).clamp(0.0, 1.0),
      );

  void _erase(Offset norm) {
    // Radius scales with highlighter-ish finger size: 2% of page width.
    final hit = widget.strokes
        .where((s) => s.hitTest(norm, 0.02))
        .toList(growable: false);
    if (hit.isEmpty) return;
    final next = [...widget.strokes]..removeWhere(hit.contains);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: widget.drawEnabled
              ? HitTestBehavior.opaque
              : HitTestBehavior.translucent,
          onPanStart: !widget.drawEnabled
              ? null
              : (d) {
                  final n = _normalize(d.localPosition, size);
                  if (widget.config.eraser) {
                    _erase(n);
                  } else {
                    setState(() => _inProgress = [n.dx, n.dy]);
                  }
                },
          onPanUpdate: !widget.drawEnabled
              ? null
              : (d) {
                  final n = _normalize(d.localPosition, size);
                  if (widget.config.eraser) {
                    _erase(n);
                  } else if (_inProgress != null) {
                    setState(() => _inProgress!..addAll([n.dx, n.dy]));
                  }
                },
          onPanEnd: !widget.drawEnabled
              ? null
              : (_) {
                  final pts = _inProgress;
                  _inProgress = null;
                  if (pts == null || pts.length < 4) {
                    setState(() {});
                    return;
                  }
                  widget.onChanged([
                    ...widget.strokes,
                    ScoreStroke(
                      tool: widget.config.tool,
                      colorValue: widget.config.color.toARGB32(),
                      width: widget.config.effectiveWidth,
                      opacity: widget.config.effectiveOpacity,
                      points: pts,
                    ),
                  ]);
                },
          child: CustomPaint(
            size: Size.infinite,
            painter: _StrokesPainter(
              strokes: widget.strokes,
              inProgress: _inProgress,
              config: widget.config,
            ),
          ),
        );
      },
    );
  }
}

class _StrokesPainter extends CustomPainter {
  final List<ScoreStroke> strokes;
  final List<double>? inProgress;
  final AnnotationToolConfig config;

  _StrokesPainter({
    required this.strokes,
    required this.inProgress,
    required this.config,
  });

  void _paintPolyline(
    Canvas canvas,
    Size size,
    List<double> pts,
    Color color,
    double normWidth,
    double opacity,
  ) {
    if (pts.length < 4) return;
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = normWidth * size.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(pts[0] * size.width, pts[1] * size.height);
    for (var i = 2; i + 1 < pts.length; i += 2) {
      path.lineTo(pts[i] * size.width, pts[i + 1] * size.height);
    }
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      _paintPolyline(canvas, size, s.points, s.color, s.width, s.opacity);
    }
    final ip = inProgress;
    if (ip != null) {
      _paintPolyline(canvas, size, ip, config.color,
          config.effectiveWidth, config.effectiveOpacity);
    }
  }

  @override
  bool shouldRepaint(_StrokesPainter old) =>
      old.strokes != strokes ||
      old.inProgress != inProgress ||
      old.config != config;
}
