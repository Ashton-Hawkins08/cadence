import 'dart:math';
import 'dart:typed_data';

// ── Live tempo detection (BPM listening engine) ───────────────────────────────
//
// Energy-envelope onset detection + inter-onset interval (Δt) analysis:
//
//   1. RMS energy per 512-sample frame (~23 ms @ 22.05 kHz)
//   2. onset = envelope rises past (median + k·MAD) of the trailing second,
//      with a refractory gap so one drum hit can't double-trigger
//   3. Δt list → interval model → BPM
//
// Two interval models:
//
// • GENERIC (even meters — x/4, and compound x/8 where every beat is a
//   dotted quarter): beats are evenly spaced, so intervals are folded by
//   powers of two toward the running median before voting. This handles the
//   classic failure mode where subdivided playing (or a missed quiet beat)
//   produces intervals at 2× / ½× the true pulse.
//
// • MIXED METER (5/8, 7/8, 11/8): main beats are NOT evenly spaced — a
//   2+2+3 bar of 7/8 produces intervals in the ratio 2:2:3 of the eighth
//   note, so power-of-two folding would tear it apart. Instead we solve for
//   the eighth-note duration e that best explains every interval as k·e with
//   k ∈ {2,3} (plus sums like 4,5,6 for missed beats), by iterating
//   assign-ks → re-estimate e. The reported BPM is the QUARTER-note rate
//   (60000 / 2e), matching the app's metronome convention where an eighth
//   is multiplier 0.5 — so the number can be dialed straight in.
//
// Pure Dart, isolate-friendly, no dependencies.

class TempoReading {
  /// Current estimate (0 while still locking on).
  final double bpm;

  /// Number of onsets detected so far.
  final int beatCount;

  /// 0–1; how tightly recent intervals agree (1 = rock solid).
  final double stability;

  /// 0–1 live input level (post-normalization RMS) — drives the mic meter
  /// so users can SEE whether the device hears them at all.
  final double level;

  const TempoReading(this.bpm, this.beatCount, this.stability,
      [this.level = 0]);

  static const none = TempoReading(0, 0, 0);
}

class TempoAnalyzer {
  final int sampleRate;

  /// Mixed-meter mode: eighth-note lengths of the meter's main beats
  /// (e.g. [2, 2, 3] for 7/8). Empty = generic even-beat mode. Only the SET
  /// of group lengths matters for tempo — 2+2+3 and 3+2+2 detect identically.
  final List<int> beatUnits;

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

  /// Latest state for periodic status pushes (level meter, live beat count)
  /// even between onsets.
  TempoReading lastReading = TempoReading.none;
  double get currentLevel => _prevRms.clamp(0.0, 1.0);
  int get beatCount => _beatCount;

  TempoAnalyzer({this.sampleRate = 22050, this.beatUnits = const []});

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
      // RELATIVE threshold: a transient must stand well above the recent
      // envelope (2.2× its median, or 3 MADs). The original version used an
      // absolute floor of 0.008 (−42 dBFS) which sits ABOVE what a raw,
      // un-gained laptop mic delivers for a clap — so no onset ever fired.
      // The 0.002 floor only suppresses near-digital silence; real gating
      // comes from the relative terms (input arrives pre-normalized — see
      // SignalNormalizer).
      final threshold = max(median * 2.2, max(median + 3 * mad, 0.002));

      final rising = rms > threshold && _prevRms <= threshold;
      if (rising && _clockMs - _lastOnsetMs > _refractoryMs) {
        out = _registerOnset(_clockMs);
        _lastOnsetMs = _clockMs;
      }
    }
    _prevRms = rms;
    if (out != null) lastReading = out;
    return out;
  }

  static double _mad(List<double> sorted, double median) {
    final devs = sorted.map((v) => (v - median).abs()).toList()..sort();
    return devs[devs.length ~/ 2];
  }

  TempoReading _registerOnset(double tMs) {
    _beatCount++;
    if (_lastOnsetMs > -1e8) {
      final interval = tMs - _lastOnsetMs;
      if (beatUnits.isEmpty) {
        _addGenericInterval(interval);
      } else {
        // Mixed meter: store raw intervals; the unit solver interprets them.
        if (interval >= 100 && interval <= 2500) {
          _intervals.add(interval);
          if (_intervals.length > 14) _intervals.removeAt(0);
        }
      }
    }

    if (_intervals.length < 3) {
      return TempoReading(0, _beatCount, 0, currentLevel);
    }
    return beatUnits.isEmpty ? _genericReading() : _mixedMeterReading();
  }

  void _addGenericInterval(double interval) {
    var iv = interval;
    // Octave-error folding: pull the new interval toward the running
    // median by powers of two before it votes.
    if (_intervals.length >= 3) {
      final med = _median(_intervals);
      while (iv > med * 1.8 && iv / 2 >= 200) {
        iv /= 2; // heard every other beat → halve
      }
      while (iv < med * 0.55 && iv * 2 <= 1500) {
        iv *= 2; // heard a subdivision → double
      }
    }
    // Only intervals inside the app's 40–300 BPM range vote.
    if (iv >= 200 && iv <= 1500) {
      _intervals.add(iv);
      if (_intervals.length > 12) _intervals.removeAt(0);
    }
  }

  TempoReading _genericReading() {
    final med = _median(_intervals);
    final bpm = 60000.0 / med;
    // Stability: 1 − normalized spread of recent intervals.
    final spread = _mad([..._intervals]..sort(), med) / med;
    final stability = (1 - spread * 4).clamp(0.0, 1.0);
    return TempoReading(bpm, _beatCount, stability, currentLevel);
  }

  // ── Mixed-meter unit solver ─────────────────────────────────────────────────

  /// Multiples of the eighth note an interval may represent: the meter's own
  /// group lengths, plus sums of two adjacent groups (a missed quiet beat
  /// merges its two intervals — e.g. 2+3 = 5 eighths in 7/8).
  late final List<int> _allowedKs = () {
    final base = beatUnits.toSet();
    final sums = <int>{};
    for (final a in base) {
      for (final b in base) {
        sums.add(a + b);
      }
    }
    return ({...base, ...sums}.toList()..sort());
  }();

  TempoReading _mixedMeterReading() {
    // Iteratively solve for the eighth-note duration e:
    //   1. seed: assume the average interval is an average beat
    //   2. assign each interval its best k ∈ allowed multiples
    //   3. e = median of interval/k;  repeat with better assignments
    final avgUnits =
        beatUnits.fold<int>(0, (a, b) => a + b) / beatUnits.length;
    var e = _median(_intervals) / avgUnits;

    for (var iteration = 0; iteration < 3; iteration++) {
      final estimates = <double>[];
      for (final interval in _intervals) {
        final k = _bestK(interval, e);
        estimates.add(interval / k);
      }
      e = _median(estimates);
    }

    // Musical sanity: eighth between 100 ms (♩=300) and 750 ms (♩=40).
    if (e < 100 || e > 750) return TempoReading(0, _beatCount, 0);

    // Stability = fraction of intervals that fit their nearest multiple
    // within 12%. Outliers (extra ghost notes, missed onsets beyond the
    // allowed sums) reduce confidence instead of skewing the estimate.
    var fits = 0;
    for (final interval in _intervals) {
      final k = _bestK(interval, e);
      if ((interval - k * e).abs() / (k * e) <= 0.12) fits++;
    }
    final stability = fits / _intervals.length;

    // Report the QUARTER-note rate (eighth × 2) — the number the user dials
    // into the metronome for this signature.
    final bpm = 60000.0 / (2 * e);
    return TempoReading(bpm, _beatCount, stability, currentLevel);
  }

  int _bestK(double interval, double e) {
    var best = _allowedKs.first;
    var bestErr = double.infinity;
    for (final k in _allowedKs) {
      final err = (interval - k * e).abs();
      if (err < bestErr) {
        bestErr = err;
        best = k;
      }
    }
    return best;
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
    lastReading = TempoReading.none;
  }
}
