import 'dart:math';
import 'dart:typed_data';

// ── Live tempo detection (BPM listening engine) ───────────────────────────────
//
// Energy-envelope onset detection + inter-onset interval (Δt) analysis:
//
//   1. RMS energy per 512-sample frame (~23 ms @ 22.05 kHz)
//   2. onset = envelope rises past (median + k·MAD) of the trailing second,
//      with a refractory gap so one drum hit can't double-trigger
//   3. Δt list → octave folding → median → BPM
//
// Octave folding handles the classic failure mode: subdivided playing (or a
// missed quiet beat) produces intervals at 2× / ½× the true pulse. Each new
// interval is folded by powers of two toward the running median before it
// votes, so eighth-note bursts don't read as double time.
//
// Pure Dart, isolate-friendly, no dependencies.

class TempoReading {
  /// Current estimate (0 while still locking on).
  final double bpm;

  /// Number of onsets detected so far.
  final int beatCount;

  /// 0–1; how tightly recent intervals agree (1 = rock solid).
  final double stability;

  const TempoReading(this.bpm, this.beatCount, this.stability);

  static const none = TempoReading(0, 0, 0);
}

class TempoAnalyzer {
  final int sampleRate;
  static const int _frameSize = 512;

  /// Two onsets closer than this are one transient (150 ms ⇒ ceiling of
  /// 400 BPM before folding — comfortably above the app's 300 BPM max).
  static const double _refractoryMs = 150;

  /// Envelope history ≈ 1 s for the adaptive threshold.
  static const int _historyFrames = 43;

  final _envelope = <double>[];
  double _prevRms = 0;
  double _lastOnsetMs = -1e9;
  double _clockMs = 0;
  final _intervals = <double>[];
  int _beatCount = 0;

  TempoAnalyzer({this.sampleRate = 22050});

  final _pending = <int>[];

  /// Feed PCM16; returns an updated reading on each new onset, else null.
  TempoReading? process(Int16List samples) {
    TempoReading? out;
    for (final s in samples) {
      _pending.add(s);
      if (_pending.length == _frameSize) {
        final r = _processFrame();
        if (r != null) out = r;
        _pending.clear();
      }
    }
    return out;
  }

  TempoReading? _processFrame() {
    var sum = 0.0;
    for (final s in _pending) {
      final v = s / 32768.0;
      sum += v * v;
    }
    final rms = sqrt(sum / _frameSize);
    final frameMs = _frameSize * 1000.0 / sampleRate;
    _clockMs += frameMs;

    _envelope.add(rms);
    if (_envelope.length > _historyFrames) _envelope.removeAt(0);

    TempoReading? out;
    if (_envelope.length >= 8) {
      final sorted = [..._envelope]..sort();
      final median = sorted[sorted.length ~/ 2];
      final mad = _mad(sorted, median);
      // Robust threshold: quiet rooms get sensitive, loud rooms don't
      // false-trigger on breath noise.
      final threshold = median + max(4 * mad, 0.008);

      final rising = rms > threshold && _prevRms <= threshold;
      if (rising && _clockMs - _lastOnsetMs > _refractoryMs) {
        out = _registerOnset(_clockMs);
        _lastOnsetMs = _clockMs;
      }
    }
    _prevRms = rms;
    return out;
  }

  static double _mad(List<double> sorted, double median) {
    final devs = sorted.map((v) => (v - median).abs()).toList()..sort();
    return devs[devs.length ~/ 2];
  }

  TempoReading _registerOnset(double tMs) {
    _beatCount++;
    if (_lastOnsetMs > -1e8) {
      var interval = tMs - _lastOnsetMs;

      // Octave-error folding: pull the new interval toward the running
      // median by powers of two before it votes.
      if (_intervals.length >= 3) {
        final med = _median(_intervals);
        while (interval > med * 1.8 && interval / 2 >= 200) {
          interval /= 2; // heard every other beat → halve
        }
        while (interval < med * 0.55 && interval * 2 <= 1500) {
          interval *= 2; // heard a subdivision → double
        }
      }

      // Only intervals inside the app's 40–300 BPM range vote.
      if (interval >= 200 && interval <= 1500) {
        _intervals.add(interval);
        if (_intervals.length > 12) _intervals.removeAt(0);
      }
    }

    if (_intervals.length < 3) {
      return TempoReading(0, _beatCount, 0);
    }
    final med = _median(_intervals);
    final bpm = 60000.0 / med;
    // Stability: 1 − normalized spread of recent intervals.
    final spread = _mad([..._intervals]..sort(), med) / med;
    final stability = (1 - spread * 4).clamp(0.0, 1.0);
    return TempoReading(bpm, _beatCount, stability);
  }

  static double _median(List<double> xs) {
    final s = [...xs]..sort();
    return s[s.length ~/ 2];
  }

  void reset() {
    _envelope.clear();
    _intervals.clear();
    _pending.clear();
    _beatCount = 0;
    _prevRms = 0;
    _lastOnsetMs = -1e9;
    _clockMs = 0;
  }
}
