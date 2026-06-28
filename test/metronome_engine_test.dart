import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cadence/core/constants/app_constants.dart';
import 'package:cadence/core/constants/metronome_constants.dart';
import 'package:cadence/domain/services/metronome_engine.dart';

// Stub native audio channels so MetronomeEngine can be constructed and
// disposed cleanly in tests without a real native plugin.
// On Windows, _NativePool uses 'cadence/metronome'; on other platforms
// AudioPlayer uses the audioplayers channels.
void _stubAudioplayers() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final name in [
    'xyz.luan/audioplayers.global',
    'xyz.luan/audioplayers',
    'cadence/metronome',
  ]) {
    messenger.setMockMethodCallHandler(
      MethodChannel(name),
      (call) async => null,
    );
  }
}

// Await the fire-and-forget _initAudio() — it emits isAudioReady=true whether
// the native audio layer succeeds or fails (catch block), so this always
// resolves; the 5 s timeout is a safety net for CI hangs.
Future<void> _waitForInit(MetronomeEngine engine) async {
  await engine.stateStream
      .firstWhere((s) => s.isAudioReady)
      .timeout(const Duration(seconds: 5));
}

// Subscribe to the broadcast stream, run [action] synchronously, flush the
// microtask queue, cancel the subscription, and return all captured states.
Future<List<MetronomeState>> _capture(
    MetronomeEngine engine, void Function() action) async {
  final states = <MetronomeState>[];
  final sub = engine.stateStream.listen(states.add);
  action();
  await Future.delayed(Duration.zero);
  sub.cancel();
  return states;
}

void main() {
  late MetronomeEngine engine;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Must be called before the first AudioPlayer() is constructed.
    _stubAudioplayers();
  });

  setUp(() async {
    engine = MetronomeEngine();
    await _waitForInit(engine);
  });

  tearDown(() async {
    engine.stop();
    try {
      await engine.dispose();
    } catch (_) {
      // Headless test env: native audio disposal may fail; ignore.
    }
  });

  // ── Initial state ──────────────────────────────────────────────────────────

  group('initial state', () {
    test('BPM is 120', () => expect(engine.bpm, 120));

    test('not playing, not paused', () {
      expect(engine.isPlaying, isFalse);
      expect(engine.isPaused, isFalse);
    });

    test('time signature is 4/4', () {
      expect(engine.timeSignature, MetronomeTimeSignature.sig4_4);
    });

    test('subdivision is quarter', () {
      expect(engine.subdivision, MetronomeSubdivision.quarter);
    });

    test('accent first beat is true', () {
      expect(engine.accentFirstBeat, isTrue);
    });

    test('currentSectionIndex is 0', () {
      expect(engine.currentSectionIndex, 0);
    });

    test('stateStream carries isAudioReady=true after init', () async {
      // Trigger an emission so we can observe the current state value.
      final states = await _capture(engine, () => engine.setBpm(engine.bpm));
      expect(states, isNotEmpty);
      expect(states.last.isAudioReady, isTrue);
    });
  });

  // ── setBpm ─────────────────────────────────────────────────────────────────

  group('setBpm', () {
    test('normal value is stored', () {
      engine.setBpm(140);
      expect(engine.bpm, 140);
    });

    test('clamps to minBpm when below range', () {
      engine.setBpm(0);
      expect(engine.bpm, AppConstants.minBpm);
    });

    test('clamps to minBpm for negative input', () {
      engine.setBpm(-50);
      expect(engine.bpm, AppConstants.minBpm);
    });

    test('clamps to maxBpm when above range', () {
      engine.setBpm(99999);
      expect(engine.bpm, AppConstants.maxBpm);
    });

    test('exactly minBpm is stored unchanged', () {
      engine.setBpm(AppConstants.minBpm);
      expect(engine.bpm, AppConstants.minBpm);
    });

    test('exactly maxBpm is stored unchanged', () {
      engine.setBpm(AppConstants.maxBpm);
      expect(engine.bpm, AppConstants.maxBpm);
    });

    test('emits updated BPM on stateStream', () async {
      final states = await _capture(engine, () => engine.setBpm(180));
      expect(states.any((s) => s.bpm == 180), isTrue);
    });
  });

  // ── tapTempo ───────────────────────────────────────────────────────────────

  group('tapTempo', () {
    test('single tap does not change BPM', () {
      final before = engine.bpm;
      engine.tapTempo();
      expect(engine.bpm, before);
    });

    test('two taps 500 ms apart → ~120 BPM', () async {
      engine.tapTempo();
      await Future.delayed(const Duration(milliseconds: 500));
      engine.tapTempo();
      // 60000 / 500 = 120 BPM; ±5 tolerance for CI timing imprecision
      expect(engine.bpm, closeTo(120, 5));
    });

    test('four taps at ~333 ms apart → ~180 BPM', () async {
      for (var i = 0; i < 4; i++) {
        engine.tapTempo();
        if (i < 3) await Future.delayed(const Duration(milliseconds: 333));
      }
      expect(engine.bpm, closeTo(180, 10));
    });

    test('stale gap (>3 s) resets buffer — old tap is discarded', () async {
      engine.tapTempo(); // tap #1
      // >3 s gap: the next tapTempo call clears the buffer (our fix).
      await Future.delayed(const Duration(milliseconds: 3100));
      engine.tapTempo(); // tap #2 — clears buffer, only 1 tap remains
      // Only 1 entry in buffer → BPM cannot be calculated → unchanged at 120
      expect(engine.bpm, 120);
      // Now a second tap 500 ms later should give ~120 BPM from a fresh pair.
      await Future.delayed(const Duration(milliseconds: 500));
      engine.tapTempo();
      expect(engine.bpm, closeTo(120, 5));
    });

    test('tap buffer capped at 8 entries — no crash on overflow', () async {
      for (var i = 0; i < 10; i++) {
        engine.tapTempo();
        await Future.delayed(const Duration(milliseconds: 50));
      }
      expect(engine.bpm, greaterThan(0));
    });

    test('result clamped to maxBpm for extremely fast taps', () async {
      engine.tapTempo();
      await Future.delayed(const Duration(milliseconds: 1));
      engine.tapTempo();
      expect(engine.bpm, lessThanOrEqualTo(AppConstants.maxBpm));
    });
  });

  // ── setTimeSignature ───────────────────────────────────────────────────────

  group('setTimeSignature', () {
    test('changes stored time signature', () {
      engine.setTimeSignature(MetronomeTimeSignature.sig3_4);
      expect(engine.timeSignature, MetronomeTimeSignature.sig3_4);
    });

    test('switching to 6/8 resets subdivision to a compatible one', () {
      engine.setTimeSignature(MetronomeTimeSignature.sig6_8);
      expect(
        MetronomeTimeSignature.sig6_8.availableSubdivisions,
        contains(engine.subdivision),
      );
    });

    test('emits updated state on stateStream', () async {
      final states = await _capture(
          engine, () => engine.setTimeSignature(MetronomeTimeSignature.sig5_4));
      expect(states.any((s) => s.timeSignature == MetronomeTimeSignature.sig5_4),
          isTrue);
    });
  });

  // ── setSubdivision ─────────────────────────────────────────────────────────

  group('setSubdivision', () {
    test('changes stored subdivision', () {
      engine.setSubdivision(MetronomeSubdivision.sixteenth);
      expect(engine.subdivision, MetronomeSubdivision.sixteenth);
    });

    test('emits updated state on stateStream', () async {
      final states = await _capture(
          engine, () => engine.setSubdivision(MetronomeSubdivision.triplet));
      expect(states.any((s) => s.subdivision == MetronomeSubdivision.triplet),
          isTrue);
    });
  });

  // ── setAccentFirstBeat ─────────────────────────────────────────────────────

  group('setAccentFirstBeat', () {
    test('false is stored', () {
      engine.setAccentFirstBeat(false);
      expect(engine.accentFirstBeat, isFalse);
    });

    test('false emits on stateStream', () async {
      final states =
          await _capture(engine, () => engine.setAccentFirstBeat(false));
      expect(states.any((s) => s.accentFirstBeat == false), isTrue);
    });

    test('true restores after false', () {
      engine.setAccentFirstBeat(false);
      engine.setAccentFirstBeat(true);
      expect(engine.accentFirstBeat, isTrue);
    });
  });

  // ── start / stop ───────────────────────────────────────────────────────────

  group('start / stop', () {
    test('start() → isPlaying=true, isPaused=false', () async {
      final states = await _capture(engine, () => engine.start());
      final started = states.lastWhere((s) => s.isPlaying);
      expect(started.isPlaying, isTrue);
      expect(started.isPaused, isFalse);
    });

    test('stop() after start() → isPlaying=false, isPaused=false', () async {
      final states = await _capture(engine, () {
        engine.start();
        engine.stop();
      });
      final stopped = states.lastWhere((s) => !s.isPlaying);
      expect(stopped.isPlaying, isFalse);
      expect(stopped.isPaused, isFalse);
    });

    test('stop() resets currentMeasure to 1', () async {
      final states =
          await _capture(engine, () => engine.stop()); // stop on fresh engine
      expect(states.last.currentMeasure, 1);
    });

    test('stop() resets visualBeatIndex to 0', () async {
      final states = await _capture(engine, () {
        engine.start();
        engine.stop();
      });
      final stopped = states.last;
      expect(stopped.visualBeatIndex, 0);
    });

    test('double start() restarts cleanly with currentMeasure=1', () async {
      final states = await _capture(engine, () {
        engine.start();
        engine.start(); // stop + restart
      });
      // The last emitted start state should show playing and measure=1
      final started = states.lastWhere((s) => s.isPlaying);
      expect(started.currentMeasure, 1);
      expect(started.isPlaying, isTrue);
    });

    test('stop() when already stopped does not throw', () {
      expect(() => engine.stop(), returnsNormally);
    });

    test('isPlaying getter reflects current state', () {
      expect(engine.isPlaying, isFalse);
      engine.start();
      expect(engine.isPlaying, isTrue);
      engine.stop();
      expect(engine.isPlaying, isFalse);
    });
  });

  // ── pause / resume ─────────────────────────────────────────────────────────

  group('pause / resume', () {
    test('pause() while playing → isPaused=true, isPlaying=true', () async {
      final states = await _capture(engine, () {
        engine.start();
        engine.pause();
      });
      final paused = states.lastWhere((s) => s.isPaused);
      expect(paused.isPaused, isTrue);
      expect(paused.isPlaying, isTrue);
    });

    test('resume() after pause → isPaused=false, isPlaying=true', () async {
      final states = await _capture(engine, () {
        engine.start();
        engine.pause();
        engine.resume();
      });
      final resumed = states.last;
      expect(resumed.isPaused, isFalse);
      expect(resumed.isPlaying, isTrue);
    });

    test('pause() when not playing is a no-op (no state change)', () {
      engine.pause(); // guard: if (!_isPlaying || _isPaused) return
      expect(engine.isPaused, isFalse);
      expect(engine.isPlaying, isFalse);
    });

    test('resume() when not paused is a no-op', () {
      engine.start();
      engine.resume(); // guard: if (!_isPaused) return
      expect(engine.isPaused, isFalse);
      expect(engine.isPlaying, isTrue);
    });

    test('double pause() emits only one isPaused=true event', () async {
      final states = await _capture(engine, () {
        engine.start();
        engine.pause();
        engine.pause(); // second call is a no-op — emits nothing extra
      });
      final pausedCount = states.where((s) => s.isPaused).length;
      expect(pausedCount, 1);
    });

    test('isPaused getter tracks state', () {
      engine.start();
      expect(engine.isPaused, isFalse);
      engine.pause();
      expect(engine.isPaused, isTrue);
      engine.resume();
      expect(engine.isPaused, isFalse);
    });
  });

  // ── stateStream emission coverage ─────────────────────────────────────────

  group('stateStream', () {
    test('setBpm emits exactly once', () async {
      final states = await _capture(engine, () => engine.setBpm(99));
      expect(states.where((s) => s.bpm == 99).length, 1);
    });

    test('setTimeSignature emits exactly once', () async {
      final states = await _capture(
          engine, () => engine.setTimeSignature(MetronomeTimeSignature.sig7_8));
      expect(states.where((s) => s.timeSignature == MetronomeTimeSignature.sig7_8).length,
          1);
    });

    test('start() + stop() produce at least two emissions', () async {
      final states = await _capture(engine, () {
        engine.start();
        engine.stop();
      });
      // start emits, stop emits — at least 2
      expect(states.length, greaterThanOrEqualTo(2));
    });

    test('stream is a broadcast — multiple simultaneous listeners ok', () async {
      final a = <MetronomeState>[];
      final b = <MetronomeState>[];
      final subA = engine.stateStream.listen(a.add);
      final subB = engine.stateStream.listen(b.add);
      engine.setBpm(77);
      await Future.delayed(Duration.zero);
      subA.cancel();
      subB.cancel();
      expect(a.any((s) => s.bpm == 77), isTrue);
      expect(b.any((s) => s.bpm == 77), isTrue);
    });
  });

  // ── piece mode: onSectionChanged / onPieceComplete ────────────────────────

  group('piece mode callbacks', () {
    test('onPieceComplete fires when single-section piece finishes', () async {
      // 1/4 at maxBpm → each measure ≈ 200 ms; very fast piece.
      final config = [
        SectionConfig(
          startMeasure: 1,
          endMeasure: 1,
          bpm: AppConstants.maxBpm,
          timeSignature: MetronomeTimeSignature.sig1_4,
          subdivision: MetronomeSubdivision.quarter,
          accentFirstBeat: false,
        ),
      ];

      var complete = false;
      engine.onPieceComplete = () => complete = true;
      engine.start(sections: config);

      // Poll up to 3 s (well past the ~200 ms needed).
      for (var i = 0; i < 30 && !complete; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      expect(complete, isTrue, reason: 'onPieceComplete should have fired');
    });

    test('onSectionChanged fires on transition from section 0 to 1', () async {
      var changedTo = -1;
      engine.onSectionChanged = (idx) => changedTo = idx;

      final configs = [
        SectionConfig(
          startMeasure: 1,
          endMeasure: 1,
          bpm: AppConstants.maxBpm,
          timeSignature: MetronomeTimeSignature.sig1_4,
          subdivision: MetronomeSubdivision.quarter,
          accentFirstBeat: false,
        ),
        SectionConfig(
          startMeasure: 2,
          endMeasure: 10,
          bpm: 60,
          timeSignature: MetronomeTimeSignature.sig4_4,
          subdivision: MetronomeSubdivision.quarter,
          accentFirstBeat: true,
        ),
      ];

      engine.start(sections: configs);

      for (var i = 0; i < 30 && changedTo == -1; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      expect(changedTo, 1, reason: 'should have transitioned to section index 1');
    });

    test('currentSectionIndex is 0 immediately after start()', () {
      final config = [
        SectionConfig(
          startMeasure: 1,
          endMeasure: 100,
          bpm: 60,
          timeSignature: MetronomeTimeSignature.sig4_4,
          subdivision: MetronomeSubdivision.quarter,
          accentFirstBeat: true,
        ),
      ];
      engine.start(sections: config);
      expect(engine.currentSectionIndex, 0);
    });

    test('stop() after piece start clears section state', () async {
      final config = [
        SectionConfig(
          startMeasure: 1,
          endMeasure: 100,
          bpm: 60,
          timeSignature: MetronomeTimeSignature.sig4_4,
          subdivision: MetronomeSubdivision.quarter,
          accentFirstBeat: true,
        ),
      ];
      engine.start(sections: config);
      engine.stop();
      expect(engine.isPlaying, isFalse);
      expect(engine.currentSectionIndex, 0);
    });
  });
}
