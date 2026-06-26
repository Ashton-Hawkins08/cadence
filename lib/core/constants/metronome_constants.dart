import 'dart:math';

// ── Beat level ────────────────────────────────────────────────────────────────
enum BeatLevel { downbeat, beat, subdivision }

// ── Single tick in a measure's pattern ───────────────────────────────────────
// quarterNoteMultiplier: how many quarter notes this tick lasts before the next
class MetronomeTick {
  final double quarterNoteMultiplier;
  final BeatLevel level;
  const MetronomeTick(this.quarterNoteMultiplier, this.level);
}

// ── Subdivision options ───────────────────────────────────────────────────────
enum MetronomeSubdivision {
  // x/4 simple time
  quarter('Quarter Notes'),
  eighth('Eighth Notes'),
  sixteenth('Sixteenth Notes'),
  triplet('Triplets'),
  // x/8 compound time (3/8, 6/8, 9/8, 12/8)
  dottedQuarter('Dotted Quarters'),
  compoundEighth('Eighth Notes'),
  compoundSixteenth('Sixteenth Notes'),
  // 5/8 asymmetrical
  fiveEight2_3('2+3 Eighths'),
  fiveEight3_2('3+2 Eighths'),
  fiveEight2_3_beats('2+3 Beats Only'),
  fiveEight3_2_beats('3+2 Beats Only'),
  // 7/8 asymmetrical
  sevenEight2_2_3('2+2+3 Eighths'),
  sevenEight2_3_2('2+3+2 Eighths'),
  sevenEight3_2_2('3+2+2 Eighths'),
  sevenEight2_2_3_beats('2+2+3 Beats Only'),
  sevenEight2_3_2_beats('2+3+2 Beats Only'),
  sevenEight3_2_2_beats('3+2+2 Beats Only'),
  // 11/8 asymmetrical
  elevenEight3_3_3_2('3+3+3+2 Eighths'),
  elevenEight4_3_4('4+3+4 Eighths'),
  elevenEight2_3_3_3('2+3+3+3 Eighths'),
  elevenEight3_3_3_2_beats('3+3+3+2 Beats Only'),
  elevenEight4_3_4_beats('4+3+4 Beats Only'),
  elevenEight2_3_3_3_beats('2+3+3+3 Beats Only');

  final String displayName;
  const MetronomeSubdivision(this.displayName);
}

// ── Time signatures ───────────────────────────────────────────────────────────
enum MetronomeTimeSignature {
  sig1_4('1/4', 1, 4),
  sig2_4('2/4', 2, 4),
  sig3_4('3/4', 3, 4),
  sig4_4('4/4', 4, 4),
  sig5_4('5/4', 5, 4),
  sig6_4('6/4', 6, 4),
  sig3_8('3/8', 3, 8),
  sig5_8('5/8', 5, 8),
  sig6_8('6/8', 6, 8),
  sig7_8('7/8', 7, 8),
  sig9_8('9/8', 9, 8),
  sig11_8('11/8', 11, 8),
  sig12_8('12/8', 12, 8);

  final String display;
  final int numerator;
  final int denominator;
  const MetronomeTimeSignature(this.display, this.numerator, this.denominator);

  List<MetronomeSubdivision> get availableSubdivisions {
    switch (this) {
      case sig1_4:
      case sig2_4:
      case sig3_4:
      case sig4_4:
      case sig5_4:
      case sig6_4:
        return [
          MetronomeSubdivision.quarter,
          MetronomeSubdivision.eighth,
          MetronomeSubdivision.sixteenth,
          MetronomeSubdivision.triplet,
        ];
      case sig3_8:
        return [
          MetronomeSubdivision.dottedQuarter,
          MetronomeSubdivision.compoundEighth,
          MetronomeSubdivision.compoundSixteenth,
        ];
      case sig5_8:
        return [
          MetronomeSubdivision.fiveEight2_3,
          MetronomeSubdivision.fiveEight2_3_beats,
          MetronomeSubdivision.fiveEight3_2,
          MetronomeSubdivision.fiveEight3_2_beats,
        ];
      case sig6_8:
        return [
          MetronomeSubdivision.dottedQuarter,
          MetronomeSubdivision.compoundEighth,
          MetronomeSubdivision.compoundSixteenth,
        ];
      case sig7_8:
        return [
          MetronomeSubdivision.sevenEight2_2_3,
          MetronomeSubdivision.sevenEight2_2_3_beats,
          MetronomeSubdivision.sevenEight2_3_2,
          MetronomeSubdivision.sevenEight2_3_2_beats,
          MetronomeSubdivision.sevenEight3_2_2,
          MetronomeSubdivision.sevenEight3_2_2_beats,
        ];
      case sig9_8:
        return [
          MetronomeSubdivision.dottedQuarter,
          MetronomeSubdivision.compoundEighth,
          MetronomeSubdivision.compoundSixteenth,
        ];
      case sig11_8:
        return [
          MetronomeSubdivision.elevenEight3_3_3_2,
          MetronomeSubdivision.elevenEight3_3_3_2_beats,
          MetronomeSubdivision.elevenEight4_3_4,
          MetronomeSubdivision.elevenEight4_3_4_beats,
          MetronomeSubdivision.elevenEight2_3_3_3,
          MetronomeSubdivision.elevenEight2_3_3_3_beats,
        ];
      case sig12_8:
        return [
          MetronomeSubdivision.dottedQuarter,
          MetronomeSubdivision.compoundEighth,
          MetronomeSubdivision.compoundSixteenth,
        ];
    }
  }

  MetronomeSubdivision get defaultSubdivision => availableSubdivisions.first;
}

// ── Tick pattern builder ──────────────────────────────────────────────────────
// Returns the ordered list of ticks that constitute one full measure.
// BPM is always expressed as quarter-notes-per-minute; quarterNoteMultiplier
// on each tick determines its duration relative to that reference.

List<MetronomeTick> buildTickPattern(
  MetronomeTimeSignature ts,
  MetronomeSubdivision sub,
) {
  final n = ts.numerator;

  MetronomeTick t(double mult, BeatLevel level) => MetronomeTick(mult, level);
  BeatLevel levelFor(int i, List<int> beatPositions) {
    if (i == 0) return BeatLevel.downbeat;
    if (beatPositions.contains(i)) return BeatLevel.beat;
    return BeatLevel.subdivision;
  }

  switch (sub) {
    // ── Simple x/4 ──────────────────────────────────────────────────────────
    case MetronomeSubdivision.quarter:
      return List.generate(
          n, (i) => t(1.0, i == 0 ? BeatLevel.downbeat : BeatLevel.beat));

    case MetronomeSubdivision.eighth:
      return List.generate(2 * n, (i) {
        if (i == 0) return t(0.5, BeatLevel.downbeat);
        if (i % 2 == 0) return t(0.5, BeatLevel.beat);
        return t(0.5, BeatLevel.subdivision);
      });

    case MetronomeSubdivision.sixteenth:
      return List.generate(4 * n, (i) {
        if (i == 0) return t(0.25, BeatLevel.downbeat);
        if (i % 4 == 0) return t(0.25, BeatLevel.beat);
        return t(0.25, BeatLevel.subdivision);
      });

    case MetronomeSubdivision.triplet:
      return List.generate(3 * n, (i) {
        if (i == 0) return t(1 / 3, BeatLevel.downbeat);
        if (i % 3 == 0) return t(1 / 3, BeatLevel.beat);
        return t(1 / 3, BeatLevel.subdivision);
      });

    // ── Compound x/8: dotted-quarter = 3 eighths ────────────────────────────
    case MetronomeSubdivision.dottedQuarter:
      final count = max(1, n ~/ 3);
      return List.generate(
          count, (i) => t(1.5, i == 0 ? BeatLevel.downbeat : BeatLevel.beat));

    case MetronomeSubdivision.compoundEighth:
      return List.generate(n, (i) {
        if (i == 0) return t(0.5, BeatLevel.downbeat);
        if (i % 3 == 0) return t(0.5, BeatLevel.beat);
        return t(0.5, BeatLevel.subdivision);
      });

    case MetronomeSubdivision.compoundSixteenth:
      return List.generate(2 * n, (i) {
        if (i == 0) return t(0.25, BeatLevel.downbeat);
        if (i % 6 == 0) return t(0.25, BeatLevel.beat);
        return t(0.25, BeatLevel.subdivision);
      });

    // ── 5/8 asymmetrical ────────────────────────────────────────────────────
    case MetronomeSubdivision.fiveEight2_3:
      return List.generate(5, (i) => t(0.5, levelFor(i, [2])));

    case MetronomeSubdivision.fiveEight3_2:
      return List.generate(5, (i) => t(0.5, levelFor(i, [3])));

    case MetronomeSubdivision.fiveEight2_3_beats:
      return [t(1.0, BeatLevel.downbeat), t(1.5, BeatLevel.beat)];

    case MetronomeSubdivision.fiveEight3_2_beats:
      return [t(1.5, BeatLevel.downbeat), t(1.0, BeatLevel.beat)];

    // ── 7/8 asymmetrical ────────────────────────────────────────────────────
    case MetronomeSubdivision.sevenEight2_2_3:
      return List.generate(7, (i) => t(0.5, levelFor(i, [2, 4])));

    case MetronomeSubdivision.sevenEight2_3_2:
      return List.generate(7, (i) => t(0.5, levelFor(i, [2, 5])));

    case MetronomeSubdivision.sevenEight3_2_2:
      return List.generate(7, (i) => t(0.5, levelFor(i, [3, 5])));

    case MetronomeSubdivision.sevenEight2_2_3_beats:
      return [t(1.0, BeatLevel.downbeat), t(1.0, BeatLevel.beat), t(1.5, BeatLevel.beat)];

    case MetronomeSubdivision.sevenEight2_3_2_beats:
      return [t(1.0, BeatLevel.downbeat), t(1.5, BeatLevel.beat), t(1.0, BeatLevel.beat)];

    case MetronomeSubdivision.sevenEight3_2_2_beats:
      return [t(1.5, BeatLevel.downbeat), t(1.0, BeatLevel.beat), t(1.0, BeatLevel.beat)];

    // ── 11/8 asymmetrical ───────────────────────────────────────────────────
    case MetronomeSubdivision.elevenEight3_3_3_2:
      // groups: [0,1,2] [3,4,5] [6,7,8] [9,10]
      return List.generate(11, (i) => t(0.5, levelFor(i, [3, 6, 9])));

    case MetronomeSubdivision.elevenEight4_3_4:
      // groups: [0,1,2,3] [4,5,6] [7,8,9,10]
      return List.generate(11, (i) => t(0.5, levelFor(i, [4, 7])));

    case MetronomeSubdivision.elevenEight2_3_3_3:
      // groups: [0,1] [2,3,4] [5,6,7] [8,9,10]
      return List.generate(11, (i) => t(0.5, levelFor(i, [2, 5, 8])));

    case MetronomeSubdivision.elevenEight3_3_3_2_beats:
      return [t(1.5, BeatLevel.downbeat), t(1.5, BeatLevel.beat), t(1.5, BeatLevel.beat), t(1.0, BeatLevel.beat)];

    case MetronomeSubdivision.elevenEight4_3_4_beats:
      return [t(2.0, BeatLevel.downbeat), t(1.5, BeatLevel.beat), t(2.0, BeatLevel.beat)];

    case MetronomeSubdivision.elevenEight2_3_3_3_beats:
      return [t(1.0, BeatLevel.downbeat), t(1.5, BeatLevel.beat), t(1.5, BeatLevel.beat), t(1.5, BeatLevel.beat)];
  }
}
