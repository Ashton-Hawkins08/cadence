import 'dart:typed_data';

// ── Deterministic software gain (AGC) ─────────────────────────────────────────
//
// Mic capture is configured RAW — OS auto-gain isn't implemented on every
// record backend, and is non-deterministic where it is. But raw laptop/phone
// mics often peak at 1–5% of full scale, which starves level-dependent
// detection (the Tempo Ear's onset thresholds especially).
//
// This tracker scales each chunk so recent peaks sit near half scale:
//   • rises INSTANTLY to loud input (no clipping surprise),
//   • decays slowly (~2 s of chunks) when things go quiet,
//   • never gains above ×48, and never below ×1,
// Pure gain — frequency content (pitch) is untouched.

class SignalNormalizer {
  /// Running peak in raw int16 units. Starts low so quiet input gets useful
  /// gain within the first few chunks.
  double _trackedPeak = 512.0;

  static const double _decayPerChunk = 0.99;
  static const double _peakFloor = 96.0; // stops gain winding into noise
  static const double _maxGain = 48.0;
  static const double _target = 16384.0; // half of int16 full scale

  /// Scales [samples] in place; returns the gain that was applied.
  double normalize(Int16List samples) {
    var chunkPeak = 1;
    for (final s in samples) {
      final mag = s < 0 ? -s : s;
      if (mag > chunkPeak) chunkPeak = mag;
    }

    _trackedPeak = chunkPeak > _trackedPeak
        ? chunkPeak.toDouble()
        : _trackedPeak * _decayPerChunk;
    if (_trackedPeak < _peakFloor) _trackedPeak = _peakFloor;

    final gain = (_target / _trackedPeak).clamp(1.0, _maxGain);
    if (gain > 1.05) {
      for (var i = 0; i < samples.length; i++) {
        samples[i] = (samples[i] * gain).round().clamp(-32767, 32767);
      }
    }
    return gain;
  }
}
