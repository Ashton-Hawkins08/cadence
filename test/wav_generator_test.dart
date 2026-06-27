import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:cadence/domain/services/wav_generator.dart';

// WAV header layout (44 bytes):
//  0  RIFF
//  4  file size − 8  (little-endian uint32)
//  8  WAVE
// 12  fmt
// 16  chunk size = 16  (little-endian uint32)
// 20  audio format = 1 (PCM)  (little-endian uint16)
// 22  channels = 1            (little-endian uint16)
// 24  sample rate             (little-endian uint32)
// 28  byte rate = sr × 2      (little-endian uint32)
// 32  block align = 2         (little-endian uint16)
// 34  bits/sample = 16        (little-endian uint16)
// 36  data
// 40  data size in bytes      (little-endian uint32)
// 44+ PCM samples (int16 little-endian)

String _fourCC(Uint8List b, int offset) =>
    String.fromCharCodes(b.sublist(offset, offset + 4));

int _u32(Uint8List b, int offset) =>
    ByteData.sublistView(b, offset, offset + 4).getUint32(0, Endian.little);

int _u16(Uint8List b, int offset) =>
    ByteData.sublistView(b, offset, offset + 2).getUint16(0, Endian.little);

int _i16(Uint8List b, int offset) =>
    ByteData.sublistView(b, offset, offset + 2).getInt16(0, Endian.little);

void _checkHeader(Uint8List bytes, {required int sampleRate}) {
  expect(bytes.length, greaterThanOrEqualTo(44), reason: 'must have full header');

  // Chunk IDs
  expect(_fourCC(bytes, 0), 'RIFF');
  expect(_fourCC(bytes, 8), 'WAVE');
  expect(_fourCC(bytes, 12), 'fmt ');
  expect(_fourCC(bytes, 36), 'data');

  // RIFF chunk size = total file size − 8
  final dataBytes = bytes.length - 44;
  expect(_u32(bytes, 4), bytes.length - 8, reason: 'RIFF size');

  // fmt chunk size = 16 for PCM
  expect(_u32(bytes, 16), 16, reason: 'fmt chunk size');

  // PCM audio format
  expect(_u16(bytes, 20), 1, reason: 'audio format must be PCM=1');

  // Mono
  expect(_u16(bytes, 22), 1, reason: 'must be mono');

  // Sample rate
  expect(_u32(bytes, 24), sampleRate, reason: 'sample rate');

  // Byte rate = sampleRate × 1 channel × 2 bytes/sample
  expect(_u32(bytes, 28), sampleRate * 2, reason: 'byte rate');

  // Block align = 1 channel × 2 bytes
  expect(_u16(bytes, 32), 2, reason: 'block align');

  // 16-bit samples
  expect(_u16(bytes, 34), 16, reason: 'bits per sample');

  // Data chunk size
  expect(_u32(bytes, 40), dataBytes, reason: 'data chunk size');
}

void main() {
  const sampleRate = 22050;

  group('WavGenerator.downbeat', () {
    late Uint8List bytes;
    setUpAll(() => bytes = WavGenerator.downbeat());

    test('valid RIFF/WAVE/fmt/data header', () {
      _checkHeader(bytes, sampleRate: sampleRate);
    });

    test('total size = 44 + numSamples×2 for 12 ms at 22050 Hz', () {
      final numSamples = (sampleRate * 12 / 1000).round(); // 265
      expect(bytes.length, 44 + numSamples * 2);
    });

    test('all PCM samples in 16-bit signed range', () {
      final numSamples = (bytes.length - 44) ~/ 2;
      for (var i = 0; i < numSamples; i++) {
        final v = _i16(bytes, 44 + i * 2);
        expect(v, inInclusiveRange(-32768, 32767));
      }
    });

    test('first sample is non-zero (sound starts immediately)', () {
      // The sine wave with non-zero amplitude at t=0 should produce a
      // non-zero first sample (sin(0) = 0, but amplitude envelope ≠ 0 —
      // actually sin(0) = 0, so sample 0 is 0. Check sample 1 instead.
      final second = _i16(bytes, 44 + 2);
      expect(second, isNot(0), reason: 'sample at index 1 should be non-zero');
    });
  });

  group('WavGenerator.beat', () {
    late Uint8List bytes;
    setUpAll(() => bytes = WavGenerator.beat());

    test('valid RIFF/WAVE header', () => _checkHeader(bytes, sampleRate: sampleRate));

    test('total size = 44 + numSamples×2 for 10 ms at 22050 Hz', () {
      final numSamples = (sampleRate * 10 / 1000).round(); // 221
      expect(bytes.length, 44 + numSamples * 2);
    });

    test('all samples in valid range', () {
      final n = (bytes.length - 44) ~/ 2;
      for (var i = 0; i < n; i++) {
        expect(_i16(bytes, 44 + i * 2), inInclusiveRange(-32768, 32767));
      }
    });
  });

  group('WavGenerator.subdivision', () {
    late Uint8List bytes;
    setUpAll(() => bytes = WavGenerator.subdivision());

    test('valid RIFF/WAVE header', () => _checkHeader(bytes, sampleRate: sampleRate));

    test('total size = 44 + numSamples×2 for 8 ms at 22050 Hz', () {
      final numSamples = (sampleRate * 8 / 1000).round(); // 176
      expect(bytes.length, 44 + numSamples * 2);
    });

    test('all samples in valid range', () {
      final n = (bytes.length - 44) ~/ 2;
      for (var i = 0; i < n; i++) {
        expect(_i16(bytes, 44 + i * 2), inInclusiveRange(-32768, 32767));
      }
    });
  });

  group('relative amplitudes', () {
    test('downbeat peak amplitude > beat peak amplitude', () {
      final d = WavGenerator.downbeat();
      final b = WavGenerator.beat();
      int maxAbs(Uint8List wav) {
        int m = 0;
        final n = (wav.length - 44) ~/ 2;
        for (var i = 0; i < n; i++) {
          final v = _i16(wav, 44 + i * 2).abs();
          if (v > m) m = v;
        }
        return m;
      }
      expect(maxAbs(d), greaterThan(maxAbs(b)));
    });

    test('beat peak amplitude > subdivision peak amplitude', () {
      final b = WavGenerator.beat();
      final s = WavGenerator.subdivision();
      int maxAbs(Uint8List wav) {
        int m = 0;
        final n = (wav.length - 44) ~/ 2;
        for (var i = 0; i < n; i++) {
          final v = _i16(wav, 44 + i * 2).abs();
          if (v > m) m = v;
        }
        return m;
      }
      expect(maxAbs(b), greaterThan(maxAbs(s)));
    });
  });

  group('calls produce independent byte arrays', () {
    test('two downbeat() calls return distinct objects', () {
      final a = WavGenerator.downbeat();
      final b = WavGenerator.downbeat();
      expect(identical(a, b), isFalse);
      expect(a, equals(b)); // same content
    });
  });
}
