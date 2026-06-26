import 'dart:math';
import 'dart:typed_data';

// Generates minimal PCM WAV bytes for metronome click sounds.
// No external assets needed — sounds are synthesized at startup.
class WavGenerator {
  WavGenerator._();

  static Uint8List downbeat() =>
      _generate(frequency: 2000, durationMs: 12, decay: 260, amplitude: 0.90);

  static Uint8List beat() =>
      _generate(frequency: 1600, durationMs: 10, decay: 300, amplitude: 0.78);

  static Uint8List subdivision() =>
      _generate(frequency: 1200, durationMs: 8, decay: 400, amplitude: 0.58);

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

    // PCM — clean decaying sine, no harmonics
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
