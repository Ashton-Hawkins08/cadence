import 'dart:convert';
import 'dart:ui';

// ── Vector annotation strokes ─────────────────────────────────────────────────
//
// Annotations are stored as VECTOR PATHS, never bitmaps:
//   • coordinates are normalized to the page image (0…1 in both axes), so a
//    stroke drawn on a phone repaints pixel-perfectly on a tablet or after
//    any zoom level change;
//   • serialization is a compact JSON array per page, small enough that a
//    fully marked-up page is a few KB — repainting is a single CustomPaint
//    pass with zero decode cost.

enum StrokeTool { pen, highlighter }

class ScoreStroke {
  final StrokeTool tool;
  final int colorValue;

  /// Stroke width as a fraction of page width (device-independent).
  final double width;
  final double opacity;

  /// Flat [x0, y0, x1, y1, …] list, image-normalized.
  final List<double> points;

  const ScoreStroke({
    required this.tool,
    required this.colorValue,
    required this.width,
    required this.opacity,
    required this.points,
  });

  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {
        't': tool.index,
        'c': colorValue,
        'w': width,
        'o': opacity,
        'p': points,
      };

  factory ScoreStroke.fromJson(Map<String, dynamic> j) => ScoreStroke(
        tool: StrokeTool.values[(j['t'] as num).toInt()],
        colorValue: (j['c'] as num).toInt(),
        width: (j['w'] as num).toDouble(),
        opacity: (j['o'] as num).toDouble(),
        points: (j['p'] as List).map((e) => (e as num).toDouble()).toList(),
      );

  static String encodeList(List<ScoreStroke> strokes) =>
      jsonEncode(strokes.map((s) => s.toJson()).toList());

  static List<ScoreStroke> decodeList(String json) {
    if (json.isEmpty) return [];
    try {
      return (jsonDecode(json) as List)
          .map((e) => ScoreStroke.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return []; // corrupted annotation data must never brick the page
    }
  }

  /// Stroke-level eraser hit test: true when [p] (normalized) is within
  /// [radius] of any segment of this stroke.
  bool hitTest(Offset p, double radius) {
    if (points.length < 2) return false;
    if (points.length == 2) {
      return (Offset(points[0], points[1]) - p).distance <= radius;
    }
    for (var i = 0; i + 3 < points.length; i += 2) {
      final a = Offset(points[i], points[i + 1]);
      final b = Offset(points[i + 2], points[i + 3]);
      if (_segmentDistance(p, a, b) <= radius) return true;
    }
    return false;
  }

  static double _segmentDistance(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return (p - a).distance;
    var t = ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2;
    t = t.clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }
}
