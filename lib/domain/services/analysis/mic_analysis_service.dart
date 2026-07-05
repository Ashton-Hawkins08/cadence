import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'pitch_analyzer.dart';
import 'tempo_analyzer.dart';

// ── Microphone analysis service ───────────────────────────────────────────────
//
// Owns the mic PCM stream and a dedicated worker ISOLATE that runs the DSP
// (YIN pitch detection or onset/tempo analysis). The raw 44.1 kHz stream is
// piped straight off the platform thread into the worker; the UI isolate only
// ever receives tiny result tuples, so a busy analysis frame can never drop
// a Flutter frame — and, critically, never competes with the metronome's
// audio thread.
//
// Data flow:
//   mic (record pkg) ──Uint8List──▶ worker isolate ──(tag, a, b, c)──▶ streams
//                                   · decimate 44.1k → 22.05k
//                                   · PitchAnalyzer | TempoAnalyzer

enum AnalysisMode { pitch, tempo }

enum MicState { idle, running, denied, unsupported }

class MicAnalysisService {
  final AudioRecorder _recorder = AudioRecorder();

  Isolate? _isolate;
  SendPort? _workerPort;
  ReceivePort? _fromWorker;
  StreamSubscription<Uint8List>? _micSub;
  StreamSubscription<dynamic>? _resultSub;

  final _noteCtrl = StreamController<NoteReading?>.broadcast();
  final _tempoCtrl = StreamController<TempoReading>.broadcast();
  final _stateCtrl = StreamController<MicState>.broadcast();

  Stream<NoteReading?> get noteStream => _noteCtrl.stream;
  Stream<TempoReading> get tempoStream => _tempoCtrl.stream;
  Stream<MicState> get stateStream => _stateCtrl.stream;

  MicState _state = MicState.idle;
  MicState get state => _state;

  void _setState(MicState s) {
    _state = s;
    if (!_stateCtrl.isClosed) _stateCtrl.add(s);
  }

  Future<void> start(AnalysisMode mode) async {
    await stop();

    if (!await _recorder.hasPermission()) {
      _setState(MicState.denied);
      return;
    }

    // Worker isolate first, so no PCM chunk can arrive port-less.
    _fromWorker = ReceivePort();
    final ready = Completer<SendPort>();
    _resultSub = _fromWorker!.listen((msg) {
      if (msg is SendPort) {
        ready.complete(msg);
      } else if (msg is List && msg.isNotEmpty) {
        switch (msg[0]) {
          case 'pitch':
            final freq = msg[1] as double;
            final clarity = msg[2] as double;
            // Below ~0.6 clarity YIN is reading room noise — show "no pitch"
            // rather than a jittering wrong note.
            _noteCtrl.add(clarity >= 0.6
                ? NoteReading.fromFrequency(freq, clarity)
                : null);
          case 'tempo':
            _tempoCtrl.add(TempoReading(
                msg[1] as double, msg[2] as int, msg[3] as double));
        }
      }
    });
    _isolate = await Isolate.spawn(
      _workerMain,
      _WorkerConfig(_fromWorker!.sendPort, mode.index),
      debugName: 'cadence-mic-analysis',
    );
    _workerPort = await ready.future;

    try {
      final stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 44100,
        numChannels: 1,
        // Raw signal: DSP "helpers" distort exactly what a tuner measures.
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
      ));
      _micSub = stream.listen((bytes) => _workerPort?.send(bytes));
      _setState(MicState.running);
    } catch (_) {
      // Platform has no PCM streaming backend (or the device refused).
      await stop();
      _setState(MicState.unsupported);
    }
  }

  Future<void> stop() async {
    await _micSub?.cancel();
    _micSub = null;
    try {
      if (await _recorder.isRecording()) await _recorder.stop();
    } catch (_) {}
    await _resultSub?.cancel();
    _resultSub = null;
    _fromWorker?.close();
    _fromWorker = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _workerPort = null;
    if (_state == MicState.running) _setState(MicState.idle);
  }

  Future<void> dispose() async {
    await stop();
    await _noteCtrl.close();
    await _tempoCtrl.close();
    await _stateCtrl.close();
    _recorder.dispose();
  }
}

// ── Worker isolate ────────────────────────────────────────────────────────────

class _WorkerConfig {
  final SendPort out;
  final int modeIndex;
  const _WorkerConfig(this.out, this.modeIndex);
}

void _workerMain(_WorkerConfig cfg) {
  final inbox = ReceivePort();
  cfg.out.send(inbox.sendPort);

  final mode = AnalysisMode.values[cfg.modeIndex];
  // Both analyzers run at 22.05 kHz — half the capture rate. Decimation by 2
  // (with pair-averaging as a crude anti-alias low-pass) halves the DSP cost
  // and everything musical we care about lives well below the new Nyquist.
  final pitch = PitchAnalyzer(sampleRate: 22050);
  final tempo = TempoAnalyzer(sampleRate: 22050);

  inbox.listen((msg) {
    if (msg is! Uint8List || msg.length < 4) return;

    // PCM16 little-endian → Int16, decimated 2:1 by averaging pairs.
    final bd = ByteData.sublistView(msg);
    final sampleCount = msg.length ~/ 2;
    final out = Int16List(sampleCount ~/ 2);
    for (var i = 0; i + 1 < sampleCount; i += 2) {
      final a = bd.getInt16(i * 2, Endian.little);
      final b = bd.getInt16(i * 2 + 2, Endian.little);
      out[i >> 1] = (a + b) >> 1;
    }

    switch (mode) {
      case AnalysisMode.pitch:
        final r = pitch.process(out);
        if (r != null) cfg.out.send(['pitch', r.frequency, r.clarity]);
      case AnalysisMode.tempo:
        final r = tempo.process(out);
        if (r != null) {
          cfg.out.send(['tempo', r.bpm, r.beatCount, r.stability]);
        }
    }
  });
}
