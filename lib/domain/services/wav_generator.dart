import 'dart:math';
import 'dart:typed_data';

// Generates minimal PCM WAV bytes for metronome click sounds.
// No external assets needed — sounds are synthesized at startup.
class WavGenerator {
  WavGenerator._();

  static Uint8List downbeat() =>
      _generate(frequency: 1800, durationMs: 22, decay: 100, amplitude: 0.88);

  static Uint8List beat() =>
      _generate(frequency: 1400, durationMs: 18, decay: 110, amplitude: 0.75);

  static Uint8List subdivision() =>
      _generate(frequency: 1050, durationMs: 14, decay: 120, amplitude: 0.55);

  static Uint8List _generate({
    required double frequency,
    required int durationMs,
    required double decay,
    required double amplitude,
    int sampleRate = 22050,
  }) {
    final numSamples = (sampleRate * durationMs / 1000).round();
    final dataBytes = numSamples * 2; // 16-bit mono
    final buf = ByteData(44 + dataBytes);

    // RIFF header
    _setFourCC(buf, 0, 'RIFF');
    buf.setUint32(4, 36 + dataBytes, Endian.little);
    _setFourCC(buf, 8, 'WAVE');
    // fmt chunk
    _setFourCC(buf, 12, 'fmt ');
    buf.setUint32(16, 16, Endian.little);
    buf.setUint16(20, 1, Endian.little);              // PCM
    buf.setUint16(22, 1, Endian.little);              // mono
    buf.setUint32(24, sampleRate, Endian.little);
    buf.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    buf.setUint16(32, 2, Endian.little);              // block align
    buf.setUint16(34, 16, Endian.little);             // bits/sample
    // data chunk
    _setFourCC(buf, 36, 'data');
    buf.setUint32(40, dataBytes, Endian.little);

    // PCM — clean decaying sine, no harmonics for a crisp click
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final env = amplitude * exp(-t * decay);
      final pcm = (env * sin(2 * pi * frequency * t) * 32767)
          .round()
          .clamp(-32768, 32767);
      buf.setInt16(44 + i * 2, pcm, Endian.little);
    }

    return buf.buffer.asUint8List();
  }

  static void _setFourCC(ByteData buf, int offset, String s) {
    for (int i = 0; i < 4; i++) {
      buf.setUint8(offset + i, s.codeUnitAt(i));
    }
  }
}
