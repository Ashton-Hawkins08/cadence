import 'dart:math';
import 'dart:typed_data';

// ── YIN pitch detection ───────────────────────────────────────────────────────
//
// de Cheveigné & Kawahara (2002) — the standard monophonic pitch algorithm:
//   1. difference function d(τ) over the analysis window
//   2. cumulative-mean-normalized difference d'(τ)  (removes the τ=0 bias)
//   3. first τ where d'(τ) dips under the threshold (absolute threshold step)
//   4. parabolic interpolation around that τ for sub-sample precision
//
// Pure Dart, no dependencies — designed to run inside a worker isolate fed by
// the microphone PCM stream. CPU cost is dominated by step 1: O(W·τmax) ≈
// 2048 × 400 ≈ 0.8M multiply-adds per frame at our sizes, comfortably
// real-time even on older phones.

class PitchReading {
  /// Detected fundamental in Hz (0 when no confident pitch).
  final double frequency;

  /// 0–1; higher = cleaner periodicity. Readings under ~0.6 are noise.
  final double clarity;

  const PitchReading(this.frequency, this.clarity);

  static const none = PitchReading(0, 0);
}

class PitchAnalyzer {
  /// Sample rate of the samples handed to [process] (after any decimation).
  final int sampleRate;

  /// Analysis window (power of two not required by YIN).
  final int windowSize;

  final double minFrequency;
  final double maxFrequency;

  /// YIN absolute threshold — 0.15 is the paper's recommended default.
  final double threshold;

  final Float64List _buffer;
  int _filled = 0;
  late final Float64List _diff;
  late final int _tauMin;
  late final int _tauMax;

  PitchAnalyzer({
    this.sampleRate = 22050,
    this.windowSize = 2048,
    this.minFrequency = 40, // E1 — covers 5-string bass / low cello
    this.maxFrequency = 2100, // ~C7 — covers piccolo/violin harmonics
    this.threshold = 0.15,
  }) : _buffer = Float64List(windowSize) {
    _tauMin = max(2, sampleRate ~/ maxFrequency.round());
    _tauMax = min(windowSize ~/ 2, (sampleRate / minFrequency).ceil());
    _diff = Float64List(_tauMax + 1);
  }

  /// Feeds PCM16 samples; returns a reading each time a full window closes,
  /// null otherwise. The window slides by half (50% overlap) for ~10 Hz of
  /// update rate at 22.05 kHz.
  PitchReading? process(Int16List samples) {
    PitchReading? last;
    for (final s in samples) {
      _buffer[_filled++] = s / 32768.0;
      if (_filled == windowSize) {
        last = _analyzeWindow();
        // Slide: keep the second half, refill from there (50% overlap).
        _buffer.setRange(0, windowSize ~/ 2, _buffer, windowSize ~/ 2);
        _filled = windowSize ~/ 2;
      }
    }
    return last;
  }

  PitchReading _analyzeWindow() {
    final w = windowSize ~/ 2;

    // Gate on level first — an idle mic must read "no pitch", not hunt for
    // periodicity in the noise floor.
    var energy = 0.0;
    for (var i = 0; i < windowSize; i++) {
      energy += _buffer[i] * _buffer[i];
    }
    if (energy / windowSize < 3e-7) return PitchReading.none; // ≈ −65 dBFS

    // 1. difference function
    for (var tau = _tauMin; tau <= _tauMax; tau++) {
      var sum = 0.0;
      for (var i = 0; i < w; i++) {
        final d = _buffer[i] - _buffer[i + tau];
        sum += d * d;
      }
      _diff[tau] = sum;
    }

    // 2. cumulative mean normalized difference
    var runningSum = 0.0;
    for (var tau = _tauMin; tau <= _tauMax; tau++) {
      runningSum += _diff[tau];
      _diff[tau] = runningSum == 0 ? 1.0 : _diff[tau] * tau / runningSum;
    }

    // 3. absolute threshold — first LOCAL MINIMUM below threshold (not the
    // global minimum: harmonics can dip lower at 2τ, causing octave errors).
    var tauEstimate = -1;
    for (var tau = _tauMin + 1; tau < _tauMax; tau++) {
      if (_diff[tau] < threshold &&
          _diff[tau] <= _diff[tau - 1] &&
          _diff[tau] <= _diff[tau + 1]) {
        tauEstimate = tau;
        break;
      }
    }
    if (tauEstimate == -1) return PitchReading.none;

    // 4. parabolic interpolation for sub-sample τ
    final y0 = _diff[tauEstimate - 1];
    final y1 = _diff[tauEstimate];
    final y2 = _diff[tauEstimate + 1];
    final denom = 2 * (2 * y1 - y2 - y0);
    final betterTau =
        denom.abs() < 1e-12 ? tauEstimate.toDouble() : tauEstimate + (y2 - y0) / denom;

    final freq = sampleRate / betterTau;
    if (freq < minFrequency || freq > maxFrequency) return PitchReading.none;
    return PitchReading(freq, (1.0 - y1).clamp(0.0, 1.0));
  }
}

// ── Musical mapping ───────────────────────────────────────────────────────────

class NoteReading {
  final String name; // e.g. "A"
  final int octave; // scientific pitch notation
  final double cents; // deviation from equal temperament, −50…+50
  final double frequency;
  final double clarity;

  const NoteReading({
    required this.name,
    required this.octave,
    required this.cents,
    required this.frequency,
    required this.clarity,
  });

  static const _names = [
    'C', 'C♯', 'D', 'D♯', 'E', 'F', 'F♯', 'G', 'G♯', 'A', 'A♯', 'B',
  ];

  /// A4 = 440 Hz equal temperament.
  static NoteReading? fromFrequency(double freq, double clarity) {
    if (freq <= 0) return null;
    final midi = 69 + 12 * (log(freq / 440.0) / ln2);
    final nearest = midi.round();
    if (nearest < 12 || nearest > 120) return null;
    return NoteReading(
      name: _names[nearest % 12],
      octave: (nearest ~/ 12) - 1,
      cents: (midi - nearest) * 100,
      frequency: freq,
      clarity: clarity,
    );
  }
}
