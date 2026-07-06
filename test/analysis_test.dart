import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:cadence/domain/services/analysis/pitch_analyzer.dart';
import 'package:cadence/domain/services/analysis/signal_normalizer.dart';
import 'package:cadence/domain/services/analysis/tempo_analyzer.dart';

// ── DSP sensitivity tests ─────────────────────────────────────────────────────
//
// These feed QUIET synthetic signals (1–2% of full scale — what a raw,
// un-gained laptop mic actually delivers) to prove the analyzers detect
// real-world input, not just ideal loud signals. Regression tests for the
// "Tempo Ear never heard a single beat" bug.

const sr = 22050;

/// Clicks (short noise bursts) at [intervalsMs], at [amplitude] of full scale,
/// over a tiny noise floor. Returned as one long PCM16 buffer.
Int16List synthesizeClicks(List<double> intervalsMs,
    {double amplitude = 0.015, double floor = 0.0006}) {
  final totalMs = intervalsMs.fold<double>(0, (a, b) => a + b) + 500;
  final n = (totalMs / 1000 * sr).round();
  final out = Int16List(n);
  final rng = Random(7);

  // noise floor
  for (var i = 0; i < n; i++) {
    out[i] = ((rng.nextDouble() * 2 - 1) * floor * 32767).round();
  }
  // clicks: 25 ms decaying noise bursts
  var tMs = 120.0; // lead-in
  for (final iv in [...intervalsMs, 0.0]) {
    final start = (tMs / 1000 * sr).round();
    final len = (0.025 * sr).round();
    for (var i = 0; i < len && start + i < n; i++) {
      final env = 1.0 - i / len;
      out[start + i] =
          ((rng.nextDouble() * 2 - 1) * amplitude * env * 32767).round();
    }
    tMs += iv;
  }
  return out;
}

/// Runs [samples] through the REAL pipeline (normalizer → analyzer) in
/// mic-like chunks; returns the final reading.
TempoReading feedTempo(TempoAnalyzer analyzer, Int16List samples) {
  final normalizer = SignalNormalizer();
  var last = TempoReading.none;
  const chunk = 1024;
  for (var i = 0; i < samples.length; i += chunk) {
    final end = min(i + chunk, samples.length);
    final piece = Int16List.fromList(samples.sublist(i, end));
    normalizer.normalize(piece);
    final r = analyzer.process(piece);
    if (r != null) last = r;
  }
  return analyzer.lastReading.beatCount > 0 ? analyzer.lastReading : last;
}

void main() {
  group('TempoAnalyzer sensitivity', () {
    test('detects quiet 120 BPM clicks (1.5% full scale)', () {
      final analyzer = TempoAnalyzer(sampleRate: sr);
      // 12 beats at 500 ms
      final pcm = synthesizeClicks(List.filled(12, 500.0));
      final r = feedTempo(analyzer, pcm);

      expect(r.beatCount, greaterThanOrEqualTo(10),
          reason: 'nearly every quiet click must register as an onset');
      expect(r.bpm, closeTo(120, 3));
      expect(r.stability, greaterThan(0.7));
    });

    test('detects very quiet 90 BPM clicks (0.8% full scale)', () {
      final analyzer = TempoAnalyzer(sampleRate: sr);
      final pcm =
          synthesizeClicks(List.filled(10, 666.7), amplitude: 0.008);
      final r = feedTempo(analyzer, pcm);

      expect(r.beatCount, greaterThanOrEqualTo(8));
      expect(r.bpm, closeTo(90, 3));
    });

    test('7/8 mixed meter (2+2+3) reports quarter-note BPM', () {
      // eighth = 250 ms → quarter = 500 ms → ♩ = 120.
      // Main-beat intervals: 2e, 2e, 3e = 500, 500, 750 ms.
      final analyzer =
          TempoAnalyzer(sampleRate: sr, beatUnits: const [2, 2, 3]);
      final bar = [500.0, 500.0, 750.0];
      final pcm = synthesizeClicks([for (var i = 0; i < 5; i++) ...bar]);
      final r = feedTempo(analyzer, pcm);

      expect(r.beatCount, greaterThanOrEqualTo(12));
      expect(r.bpm, closeTo(120, 4),
          reason: '2:2:3 intervals must resolve to the quarter rate, '
              'not get torn apart by power-of-two folding');
      expect(r.stability, greaterThan(0.7));
    });

    test('5/8 mixed meter (3+2) reports quarter-note BPM', () {
      // eighth = 300 ms → ♩ = 100. Intervals 900, 600.
      final analyzer = TempoAnalyzer(sampleRate: sr, beatUnits: const [3, 2]);
      final bar = [900.0, 600.0];
      final pcm = synthesizeClicks([for (var i = 0; i < 6; i++) ...bar]);
      final r = feedTempo(analyzer, pcm);

      expect(r.bpm, closeTo(100, 4));
    });
  });

  group('PitchAnalyzer sensitivity', () {
    test('quiet 440 Hz sine (2% full scale) reads A4', () {
      final analyzer = PitchAnalyzer(sampleRate: sr);
      final normalizer = SignalNormalizer();
      final n = sr; // 1 second
      final pcm = Int16List(n);
      for (var i = 0; i < n; i++) {
        pcm[i] = (sin(2 * pi * 440 * i / sr) * 0.02 * 32767).round();
      }
      PitchReading? last;
      const chunk = 2048;
      for (var i = 0; i + chunk <= n; i += chunk) {
        final piece = Int16List.fromList(pcm.sublist(i, i + chunk));
        normalizer.normalize(piece);
        final r = analyzer.process(piece);
        if (r != null && r.frequency > 0) last = r;
      }
      expect(last, isNotNull, reason: 'quiet sine must produce a reading');
      expect(last!.frequency, closeTo(440, 1.5));
      final note = NoteReading.fromFrequency(last.frequency, last.clarity)!;
      expect(note.name, 'A');
      expect(note.octave, 4);
      expect(note.cents.abs(), lessThan(6));
    });

    test('true silence produces no pitch', () {
      final analyzer = PitchAnalyzer(sampleRate: sr);
      final pcm = Int16List(sr); // digital zeros
      PitchReading? confident;
      const chunk = 2048;
      for (var i = 0; i + chunk <= pcm.length; i += chunk) {
        final r = analyzer.process(Int16List.sublistView(pcm, i, i + chunk));
        if (r != null && r.frequency > 0 && r.clarity >= 0.5) confident = r;
      }
      expect(confident, isNull);
    });
  });
}
