import 'package:flutter_test/flutter_test.dart';
import 'package:cadence/core/constants/metronome_constants.dart';

// Sum of all quarterNoteMultipliers in a pattern must equal the measure's
// duration in BPM units. The unit depends on the meter class (see the
// convention note in metronome_constants.dart):
//   • simple x/4 and asymmetric x/8 (5/8, 7/8, 11/8): unit = quarter note,
//     so a measure spans numerator × 4/denominator units
//   • compound x/8 (3/8, 6/8, 9/8, 12/8): unit = DOTTED QUARTER (matches
//     Dr. Beat/Korg/Boss hardware — 6/8 @120 clicks 120 dotted quarters a
//     minute), so a measure spans numerator/3 units
double _expectedDuration(MetronomeTimeSignature ts) {
  const compound = {
    MetronomeTimeSignature.sig3_8,
    MetronomeTimeSignature.sig6_8,
    MetronomeTimeSignature.sig9_8,
    MetronomeTimeSignature.sig12_8,
  };
  if (compound.contains(ts)) return ts.numerator / 3.0;
  return ts.numerator * (4 / ts.denominator);
}

double _patternDuration(List<MetronomeTick> p) =>
    p.fold(0.0, (sum, t) => sum + t.quarterNoteMultiplier);

// Count ticks whose level is not subdivision — used for visual beat dots.
int _visualBeats(List<MetronomeTick> p) =>
    p.where((t) => t.level != BeatLevel.subdivision).length;

void main() {
  // ── helpers ────────────────────────────────────────────────────────────────

  void expectDuration(MetronomeTimeSignature ts, MetronomeSubdivision sub) {
    final pattern = buildTickPattern(ts, sub);
    expect(pattern, isNotEmpty,
        reason: '${ts.display} $sub must produce at least one tick');
    expect(
      _patternDuration(pattern),
      closeTo(_expectedDuration(ts), 1e-9),
      reason: '${ts.display} $sub total duration wrong',
    );
  }

  void expectFirstIsDownbeat(MetronomeTimeSignature ts, MetronomeSubdivision sub) {
    final p = buildTickPattern(ts, sub);
    expect(p.first.level, BeatLevel.downbeat,
        reason: '${ts.display} $sub first tick must be downbeat');
  }

  // ── Total duration — simple x/4 ────────────────────────────────────────────

  group('x/4 time — total duration', () {
    const signatures = [
      MetronomeTimeSignature.sig1_4,
      MetronomeTimeSignature.sig2_4,
      MetronomeTimeSignature.sig3_4,
      MetronomeTimeSignature.sig4_4,
      MetronomeTimeSignature.sig5_4,
      MetronomeTimeSignature.sig6_4,
    ];
    const subdivisions = [
      MetronomeSubdivision.quarter,
      MetronomeSubdivision.eighth,
      MetronomeSubdivision.sixteenth,
      MetronomeSubdivision.triplet,
    ];
    for (final ts in signatures) {
      for (final sub in subdivisions) {
        test('${ts.display} / $sub', () => expectDuration(ts, sub));
      }
    }
  });

  // ── Total duration — compound x/8 ──────────────────────────────────────────

  group('compound x/8 — total duration', () {
    const sigs = [
      MetronomeTimeSignature.sig3_8,
      MetronomeTimeSignature.sig6_8,
      MetronomeTimeSignature.sig9_8,
      MetronomeTimeSignature.sig12_8,
    ];
    const subs = [
      MetronomeSubdivision.dottedQuarter,
      MetronomeSubdivision.compoundEighth,
      MetronomeSubdivision.compoundSixteenth,
    ];
    for (final ts in sigs) {
      for (final sub in subs) {
        test('${ts.display} / $sub', () => expectDuration(ts, sub));
      }
    }
  });

  // ── Total duration — 5/8 ───────────────────────────────────────────────────

  group('5/8 — total duration', () {
    const subs = [
      MetronomeSubdivision.fiveEight2_3,
      MetronomeSubdivision.fiveEight3_2,
      MetronomeSubdivision.fiveEight2_3_beats,
      MetronomeSubdivision.fiveEight3_2_beats,
    ];
    for (final sub in subs) {
      test('5/8 / $sub', () => expectDuration(MetronomeTimeSignature.sig5_8, sub));
    }
  });

  // ── Total duration — 7/8 ───────────────────────────────────────────────────

  group('7/8 — total duration', () {
    const subs = [
      MetronomeSubdivision.sevenEight2_2_3,
      MetronomeSubdivision.sevenEight2_3_2,
      MetronomeSubdivision.sevenEight3_2_2,
      MetronomeSubdivision.sevenEight2_2_3_beats,
      MetronomeSubdivision.sevenEight2_3_2_beats,
      MetronomeSubdivision.sevenEight3_2_2_beats,
    ];
    for (final sub in subs) {
      test('7/8 / $sub', () => expectDuration(MetronomeTimeSignature.sig7_8, sub));
    }
  });

  // ── Total duration — 11/8 ──────────────────────────────────────────────────

  group('11/8 — total duration', () {
    const subs = [
      MetronomeSubdivision.elevenEight3_3_3_2,
      MetronomeSubdivision.elevenEight4_3_4,
      MetronomeSubdivision.elevenEight2_3_3_3,
      MetronomeSubdivision.elevenEight3_3_3_2_beats,
      MetronomeSubdivision.elevenEight4_3_4_beats,
      MetronomeSubdivision.elevenEight2_3_3_3_beats,
    ];
    for (final sub in subs) {
      test('11/8 / $sub', () => expectDuration(MetronomeTimeSignature.sig11_8, sub));
    }
  });

  // ── First tick is always downbeat ──────────────────────────────────────────

  group('first tick is downbeat', () {
    for (final ts in MetronomeTimeSignature.values) {
      for (final sub in ts.availableSubdivisions) {
        test('${ts.display} / $sub', () => expectFirstIsDownbeat(ts, sub));
      }
    }
  });

  // ── Beat positions — specific patterns ────────────────────────────────────

  group('beat positions', () {
    test('4/4 quarter — 4 downbeat/beats, no subdivisions', () {
      final p = buildTickPattern(MetronomeTimeSignature.sig4_4, MetronomeSubdivision.quarter);
      expect(p.length, 4);
      expect(p[0].level, BeatLevel.downbeat);
      expect(p[1].level, BeatLevel.beat);
      expect(p[2].level, BeatLevel.beat);
      expect(p[3].level, BeatLevel.beat);
    });

    test('4/4 eighth — beats at indices 0,2,4,6; subs at 1,3,5,7', () {
      final p = buildTickPattern(MetronomeTimeSignature.sig4_4, MetronomeSubdivision.eighth);
      expect(p.length, 8);
      expect(p[0].level, BeatLevel.downbeat);
      expect(p[1].level, BeatLevel.subdivision);
      expect(p[2].level, BeatLevel.beat);
      expect(p[3].level, BeatLevel.subdivision);
      expect(p[6].level, BeatLevel.beat);
      expect(p[7].level, BeatLevel.subdivision);
    });

    test('4/4 sixteenth — beats at 0,4,8,12; subs elsewhere', () {
      final p = buildTickPattern(MetronomeTimeSignature.sig4_4, MetronomeSubdivision.sixteenth);
      expect(p.length, 16);
      expect(p[0].level, BeatLevel.downbeat);
      expect(p[4].level, BeatLevel.beat);
      expect(p[8].level, BeatLevel.beat);
      expect(p[12].level, BeatLevel.beat);
      for (final i in [1, 2, 3, 5, 6, 7, 9, 10, 11, 13, 14, 15]) {
        expect(p[i].level, BeatLevel.subdivision, reason: 'index $i should be sub');
      }
    });

    test('3/4 triplet — 9 ticks, beats at 0,3,6', () {
      final p = buildTickPattern(MetronomeTimeSignature.sig3_4, MetronomeSubdivision.triplet);
      expect(p.length, 9);
      expect(p[0].level, BeatLevel.downbeat);
      expect(p[3].level, BeatLevel.beat);
      expect(p[6].level, BeatLevel.beat);
      expect(p[1].level, BeatLevel.subdivision);
      expect(p[2].level, BeatLevel.subdivision);
    });

    test('6/8 compoundEighth — beats at 0 and 3', () {
      final p = buildTickPattern(MetronomeTimeSignature.sig6_8, MetronomeSubdivision.compoundEighth);
      expect(p.length, 6);
      expect(p[0].level, BeatLevel.downbeat);
      expect(p[1].level, BeatLevel.subdivision);
      expect(p[2].level, BeatLevel.subdivision);
      expect(p[3].level, BeatLevel.beat);
      expect(p[4].level, BeatLevel.subdivision);
      expect(p[5].level, BeatLevel.subdivision);
    });

    test('5/8 2+3 — beat at index 2', () {
      final p = buildTickPattern(MetronomeTimeSignature.sig5_8, MetronomeSubdivision.fiveEight2_3);
      expect(p.length, 5);
      expect(p[0].level, BeatLevel.downbeat);
      expect(p[1].level, BeatLevel.subdivision);
      expect(p[2].level, BeatLevel.beat);
      expect(p[3].level, BeatLevel.subdivision);
      expect(p[4].level, BeatLevel.subdivision);
    });

    test('5/8 3+2 — beat at index 3', () {
      final p = buildTickPattern(MetronomeTimeSignature.sig5_8, MetronomeSubdivision.fiveEight3_2);
      expect(p.length, 5);
      expect(p[0].level, BeatLevel.downbeat);
      expect(p[3].level, BeatLevel.beat);
    });

    test('5/8 2+3 beats only — 2 ticks [1.0, 1.5]', () {
      final p = buildTickPattern(MetronomeTimeSignature.sig5_8, MetronomeSubdivision.fiveEight2_3_beats);
      expect(p.length, 2);
      expect(p[0].level, BeatLevel.downbeat);
      expect(p[0].quarterNoteMultiplier, closeTo(1.0, 1e-9));
      expect(p[1].level, BeatLevel.beat);
      expect(p[1].quarterNoteMultiplier, closeTo(1.5, 1e-9));
    });

    test('5/8 3+2 beats only — 2 ticks [1.5, 1.0]', () {
      final p = buildTickPattern(MetronomeTimeSignature.sig5_8, MetronomeSubdivision.fiveEight3_2_beats);
      expect(p[0].quarterNoteMultiplier, closeTo(1.5, 1e-9));
      expect(p[1].quarterNoteMultiplier, closeTo(1.0, 1e-9));
    });

    test('7/8 2+2+3 — beats at 0,2,4', () {
      final p = buildTickPattern(MetronomeTimeSignature.sig7_8, MetronomeSubdivision.sevenEight2_2_3);
      expect(p.length, 7);
      expect(p[0].level, BeatLevel.downbeat);
      expect(p[2].level, BeatLevel.beat);
      expect(p[4].level, BeatLevel.beat);
      expect(p[1].level, BeatLevel.subdivision);
      expect(p[3].level, BeatLevel.subdivision);
      expect(p[5].level, BeatLevel.subdivision);
      expect(p[6].level, BeatLevel.subdivision);
    });

    test('7/8 2+3+2 — beats at 0,2,5', () {
      final p = buildTickPattern(MetronomeTimeSignature.sig7_8, MetronomeSubdivision.sevenEight2_3_2);
      expect(p[2].level, BeatLevel.beat);
      expect(p[5].level, BeatLevel.beat);
    });

    test('7/8 3+2+2 — beats at 0,3,5', () {
      final p = buildTickPattern(MetronomeTimeSignature.sig7_8, MetronomeSubdivision.sevenEight3_2_2);
      expect(p[3].level, BeatLevel.beat);
      expect(p[5].level, BeatLevel.beat);
    });

    test('7/8 2+2+3 beats only — 3 ticks [1.0, 1.0, 1.5]', () {
      final p = buildTickPattern(MetronomeTimeSignature.sig7_8, MetronomeSubdivision.sevenEight2_2_3_beats);
      expect(p.length, 3);
      expect(p[0].quarterNoteMultiplier, closeTo(1.0, 1e-9));
      expect(p[1].quarterNoteMultiplier, closeTo(1.0, 1e-9));
      expect(p[2].quarterNoteMultiplier, closeTo(1.5, 1e-9));
    });

    test('11/8 3+3+3+2 — beats at 0,3,6,9', () {
      final p = buildTickPattern(MetronomeTimeSignature.sig11_8, MetronomeSubdivision.elevenEight3_3_3_2);
      expect(p.length, 11);
      expect(p[0].level, BeatLevel.downbeat);
      expect(p[3].level, BeatLevel.beat);
      expect(p[6].level, BeatLevel.beat);
      expect(p[9].level, BeatLevel.beat);
    });

    test('11/8 4+3+4 — beats at 0,4,7', () {
      final p = buildTickPattern(MetronomeTimeSignature.sig11_8, MetronomeSubdivision.elevenEight4_3_4);
      expect(p[0].level, BeatLevel.downbeat);
      expect(p[4].level, BeatLevel.beat);
      expect(p[7].level, BeatLevel.beat);
    });

    test('11/8 2+3+3+3 — beats at 0,2,5,8', () {
      final p = buildTickPattern(MetronomeTimeSignature.sig11_8, MetronomeSubdivision.elevenEight2_3_3_3);
      expect(p[0].level, BeatLevel.downbeat);
      expect(p[2].level, BeatLevel.beat);
      expect(p[5].level, BeatLevel.beat);
      expect(p[8].level, BeatLevel.beat);
    });

    test('11/8 3+3+3+2 beats only — 4 ticks [1.5,1.5,1.5,1.0]', () {
      final p = buildTickPattern(MetronomeTimeSignature.sig11_8, MetronomeSubdivision.elevenEight3_3_3_2_beats);
      expect(p.length, 4);
      expect(p[0].quarterNoteMultiplier, closeTo(1.5, 1e-9));
      expect(p[3].quarterNoteMultiplier, closeTo(1.0, 1e-9));
    });

    test('11/8 4+3+4 beats only — 3 ticks [2.0,1.5,2.0]', () {
      final p = buildTickPattern(MetronomeTimeSignature.sig11_8, MetronomeSubdivision.elevenEight4_3_4_beats);
      expect(p.length, 3);
      expect(p[0].quarterNoteMultiplier, closeTo(2.0, 1e-9));
      expect(p[1].quarterNoteMultiplier, closeTo(1.5, 1e-9));
      expect(p[2].quarterNoteMultiplier, closeTo(2.0, 1e-9));
    });
  });

  // ── Visual beat counts ─────────────────────────────────────────────────────

  group('visual beat count (non-subdivision ticks)', () {
    test('4/4 quarter → 4', () {
      final p = buildTickPattern(MetronomeTimeSignature.sig4_4, MetronomeSubdivision.quarter);
      expect(_visualBeats(p), 4);
    });

    test('4/4 eighth → 4', () {
      final p = buildTickPattern(MetronomeTimeSignature.sig4_4, MetronomeSubdivision.eighth);
      expect(_visualBeats(p), 4);
    });

    test('4/4 sixteenth → 4', () {
      final p = buildTickPattern(MetronomeTimeSignature.sig4_4, MetronomeSubdivision.sixteenth);
      expect(_visualBeats(p), 4);
    });

    test('4/4 triplet → 4', () {
      final p = buildTickPattern(MetronomeTimeSignature.sig4_4, MetronomeSubdivision.triplet);
      expect(_visualBeats(p), 4);
    });

    test('3/4 quarter → 3', () {
      final p = buildTickPattern(MetronomeTimeSignature.sig3_4, MetronomeSubdivision.quarter);
      expect(_visualBeats(p), 3);
    });

    test('6/8 dottedQuarter → 2', () {
      final p = buildTickPattern(MetronomeTimeSignature.sig6_8, MetronomeSubdivision.dottedQuarter);
      expect(_visualBeats(p), 2);
    });

    test('6/8 compoundEighth → 2', () {
      final p = buildTickPattern(MetronomeTimeSignature.sig6_8, MetronomeSubdivision.compoundEighth);
      expect(_visualBeats(p), 2);
    });

    test('6/8 compoundSixteenth → 2', () {
      final p = buildTickPattern(MetronomeTimeSignature.sig6_8, MetronomeSubdivision.compoundSixteenth);
      expect(_visualBeats(p), 2);
    });

    test('5/8 2+3 → 2 visual beats', () {
      final p = buildTickPattern(MetronomeTimeSignature.sig5_8, MetronomeSubdivision.fiveEight2_3);
      expect(_visualBeats(p), 2);
    });

    test('5/8 2+3 beats only → 2 visual beats', () {
      final p = buildTickPattern(MetronomeTimeSignature.sig5_8, MetronomeSubdivision.fiveEight2_3_beats);
      expect(_visualBeats(p), 2);
    });

    test('7/8 2+2+3 → 3 visual beats', () {
      final p = buildTickPattern(MetronomeTimeSignature.sig7_8, MetronomeSubdivision.sevenEight2_2_3);
      expect(_visualBeats(p), 3);
    });

    test('7/8 2+2+3 beats only → 3 visual beats', () {
      final p = buildTickPattern(MetronomeTimeSignature.sig7_8, MetronomeSubdivision.sevenEight2_2_3_beats);
      expect(_visualBeats(p), 3);
    });

    test('11/8 3+3+3+2 → 4 visual beats', () {
      final p = buildTickPattern(MetronomeTimeSignature.sig11_8, MetronomeSubdivision.elevenEight3_3_3_2);
      expect(_visualBeats(p), 4);
    });

    test('11/8 4+3+4 → 3 visual beats', () {
      final p = buildTickPattern(MetronomeTimeSignature.sig11_8, MetronomeSubdivision.elevenEight4_3_4);
      expect(_visualBeats(p), 3);
    });

    test('11/8 4+3+4 beats only → 3 visual beats', () {
      final p = buildTickPattern(MetronomeTimeSignature.sig11_8, MetronomeSubdivision.elevenEight4_3_4_beats);
      expect(_visualBeats(p), 3);
    });

    test('12/8 dottedQuarter → 4', () {
      final p = buildTickPattern(MetronomeTimeSignature.sig12_8, MetronomeSubdivision.dottedQuarter);
      expect(_visualBeats(p), 4);
    });
  });

  // ── availableSubdivisions contains defaultSubdivision ─────────────────────

  group('defaultSubdivision is in availableSubdivisions', () {
    for (final ts in MetronomeTimeSignature.values) {
      test(ts.display, () {
        expect(ts.availableSubdivisions, contains(ts.defaultSubdivision));
      });
    }
  });

  // ── All multipliers are positive ───────────────────────────────────────────

  group('all quarter-note multipliers are positive', () {
    for (final ts in MetronomeTimeSignature.values) {
      for (final sub in ts.availableSubdivisions) {
        test('${ts.display} / $sub', () {
          final p = buildTickPattern(ts, sub);
          for (final tick in p) {
            expect(tick.quarterNoteMultiplier, greaterThan(0));
          }
        });
      }
    }
  });
}
