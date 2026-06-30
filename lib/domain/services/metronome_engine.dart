import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cadence/core/constants/app_constants.dart';
import 'package:cadence/core/constants/metronome_constants.dart';
import 'wav_generator.dart';

// ── Public state ──────────────────────────────────────────────────────────────

class MetronomeState {
  final bool isPlaying;
  final bool isPaused;
  final bool isAudioReady;
  final int bpm;
  final MetronomeTimeSignature timeSignature;
  final MetronomeSubdivision subdivision;
  final bool accentFirstBeat;
  // Visual dots
  final int visualBeatIndex;
  final int visualTotalBeats;
  // Full pattern info (for piece player)
  final int currentTickIndex;
  final int totalTicks;
  final int currentMeasure;
  final BeatLevel? lastFiredLevel;

  const MetronomeState({
    required this.isPlaying,
    required this.isPaused,
    required this.isAudioReady,
    required this.bpm,
    required this.timeSignature,
    required this.subdivision,
    required this.accentFirstBeat,
    required this.visualBeatIndex,
    required this.visualTotalBeats,
    required this.currentTickIndex,
    required this.totalTicks,
    required this.currentMeasure,
    this.lastFiredLevel,
  });

  static MetronomeState initial() => const MetronomeState(
        isPlaying: false,
        isPaused: false,
        isAudioReady: false,
        bpm: 120,
        timeSignature: MetronomeTimeSignature.sig4_4,
        subdivision: MetronomeSubdivision.quarter,
        accentFirstBeat: true,
        visualBeatIndex: 0,
        visualTotalBeats: 4,
        currentTickIndex: 0,
        totalTicks: 4,
        currentMeasure: 1,
      );
}

// ── Piece section config ──────────────────────────────────────────────────────

class SectionConfig {
  final int startMeasure;
  final int endMeasure;
  final int bpm;
  final MetronomeTimeSignature timeSignature;
  final MetronomeSubdivision subdivision;
  final bool accentFirstBeat;

  const SectionConfig({
    required this.startMeasure,
    required this.endMeasure,
    required this.bpm,
    required this.timeSignature,
    required this.subdivision,
    this.accentFirstBeat = true,
  });
}

// ── Audio click pool (Windows / desktop) ─────────────────────────────────────

class _ClickPool {
  static const _poolSize = 3;
  final List<AudioPlayer> _players =
      List.generate(_poolSize, (_) => AudioPlayer());
  int _index = 0;
  String? _path;
  bool _ready = false;

  Future<void> init(String path, {double volume = 1.0}) async {
    _path = path;
    for (final p in _players) {
      await p.setPlayerMode(PlayerMode.lowLatency);
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setVolume(volume); // set once — never changes per-beat
      await p.setSource(DeviceFileSource(path));
    }
    _ready = true;
  }

  // One platform channel call per beat (stop resets position; resume plays).
  // stop() before resume() guards against silent failures when the Windows
  // audio thread races with incoming completion events (threading warning).
  void fire() {
    if (!_ready || _path == null) return;
    final p = _players[_index % _poolSize];
    _index++;
    p.stop();
    p.resume();
  }

  Future<void> dispose() async {
    for (final p in _players) {
      await p.dispose();
    }
  }
}

// ── Native audio channel (Android SoundPool / Windows PlaySoundW) ────────────
//
// The native side owns audio timing — it runs a dedicated high-priority thread
// (THREAD_PRIORITY_AUDIO on Android, TIME_CRITICAL on Windows) driven by a
// hardware monotonic clock.  Dart's 4 ms polling loop handles visual state only.

class _NativePool {
  static const _ch = MethodChannel('cadence/metronome');
  bool _ready = false;

  Future<void> init(Map<String, String> paths) async {
    await _ch.invokeMethod<void>('init', paths);
    _ready = true;
  }

  // start: launches the native beat thread with the full tick pattern.
  // Returns a Future that resolves once the platform thread has called
  // startBeatThread() — i.e. the native audio beat 0 has fired (or is
  // about to within ~2 ms).  Callers can await this to align the Dart
  // visual timer with the actual native start time.
  Future<void> start(int bpm, List<Map<String, dynamic>> ticks) async {
    if (!_ready) return;
    await _ch.invokeMethod<void>('start', {'bpm': bpm, 'ticks': ticks});
  }

  void stop() {
    if (!_ready) return;
    _ch.invokeMethod<void>('stop');
  }

  void pause() {
    if (!_ready) return;
    _ch.invokeMethod<void>('pause');
  }

  void resume() {
    if (!_ready) return;
    _ch.invokeMethod<void>('resume');
  }

  // setBpm: hot-updates BPM without resetting the tick index.
  void setBpm(int bpm) {
    if (!_ready) return;
    _ch.invokeMethod<void>('setBpm', {'bpm': bpm});
  }

  // updatePattern: used for section transitions and time-sig / subdivision
  // changes. Native resets to tick 0 and restarts the interval from now.
  void updatePattern(int bpm, List<Map<String, dynamic>> ticks) {
    if (!_ready) return;
    _ch.invokeMethod<void>('updatePattern', {'bpm': bpm, 'ticks': ticks});
  }

  Future<void> dispose() async {
    if (!_ready) return;
    await _ch.invokeMethod<void>('dispose');
    _ready = false;
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

int _visualBeatsFor(MetronomeTimeSignature ts, MetronomeSubdivision sub) {
  final pattern = buildTickPattern(ts, sub);
  return pattern.where((t) => t.level != BeatLevel.subdivision).length;
}

// ── Metronome engine ──────────────────────────────────────────────────────────

class MetronomeEngine {
  // ── Config ─────────────────────────────────────────────────────────────────
  int _bpm = 120;
  MetronomeTimeSignature _timeSignature = MetronomeTimeSignature.sig4_4;
  MetronomeSubdivision _subdivision = MetronomeSubdivision.quarter;
  bool _accentFirstBeat = true;

  // ── Pattern ────────────────────────────────────────────────────────────────
  List<MetronomeTick> _pattern = [];
  int _visualTotalBeats = 4;

  // ── Playback ───────────────────────────────────────────────────────────────
  bool _isPlaying = false;
  bool _isPaused = false;
  int _tickIndex = 0;
  int _firedTickIndex = 0;
  int _visualBeatIndex = 0;
  int _currentMeasure = 1;

  // ── Piece mode ─────────────────────────────────────────────────────────────
  List<SectionConfig>? _sections;
  int _sectionIndex = 0;
  bool _pendingMeasureIncrement = false;
  void Function(int sectionIndex)? onSectionChanged;
  void Function()? onPieceComplete;

  // ── Timing ─────────────────────────────────────────────────────────────────
  final _stopwatch = Stopwatch();
  // Absolute wall-clock ms (relative to _stopwatch) at which the next beat
  // should fire. Polled every 4 ms so max jitter is 4 ms — inaudible.
  double _nextBeatMs = 0.0;
  Timer? _timer;

  // ── Audio ──────────────────────────────────────────────────────────────────
  bool _audioReady = false;
  bool _disposed = false;
  // Android + Windows: zero-threading-overhead native channel
  final _native = _NativePool();
  // macOS / Linux desktop: audioplayers click pools
  final _downbeat = _ClickPool();
  final _beat = _ClickPool();
  final _sub = _ClickPool();

  // ── Tap tempo ──────────────────────────────────────────────────────────────
  final List<int> _tapTimes = [];

  // ── State stream ───────────────────────────────────────────────────────────
  final _ctrl = StreamController<MetronomeState>.broadcast();
  Stream<MetronomeState> get stateStream => _ctrl.stream;

  MetronomeEngine() {
    _rebuildPattern();
    _initAudio();
  }

  bool get _usesNativeTiming => Platform.isAndroid || Platform.isWindows;

  void _rebuildPattern() {
    _pattern = buildTickPattern(_timeSignature, _subdivision);
    _visualTotalBeats = _visualBeatsFor(_timeSignature, _subdivision);
  }

  // ── Audio init ─────────────────────────────────────────────────────────────

  Future<void> _initAudio() async {
    if (kIsWeb || _disposed) {
      if (!_disposed) { _audioReady = true; _emit(); }
      return;
    }
    try {
      final dir = await getTemporaryDirectory();
      if (_disposed) return;
      final d = File('${dir.path}/metro_down.wav');
      final b = File('${dir.path}/metro_beat.wav');
      final s = File('${dir.path}/metro_sub.wav');
      await d.writeAsBytes(WavGenerator.downbeat());
      await b.writeAsBytes(WavGenerator.beat());
      await s.writeAsBytes(WavGenerator.subdivision());
      if (_disposed) return;
      if (_usesNativeTiming) {
        await _native.init({
          'downbeat': d.path,
          'beat': b.path,
          'sub': s.path,
        });
      } else {
        await _downbeat.init(d.path);
        await _beat.init(b.path);
        await _sub.init(s.path, volume: 0.6);
      }
      if (_disposed) return;
      _audioReady = true;
      _emit();
    } catch (_) {
      if (_disposed) return;
      _audioReady = true;
      _emit();
    }
  }

  // ── Public controls ────────────────────────────────────────────────────────

  // Builds the tick list sent to the native beat thread.
  List<Map<String, dynamic>> _buildNativeTicks() {
    return _pattern.map((tick) {
      BeatLevel effective = tick.level;
      if (tick.level == BeatLevel.downbeat && !_accentFirstBeat) {
        effective = BeatLevel.beat;
      }
      final String sound;
      final double volume;
      switch (effective) {
        case BeatLevel.downbeat:
          sound = 'downbeat'; volume = 1.0;
        case BeatLevel.beat:
          sound = 'beat'; volume = 1.0;
        case BeatLevel.subdivision:
          sound = 'sub'; volume = 0.6;
      }
      return {
        'sound': sound,
        'multiplier': tick.quarterNoteMultiplier,
        'volume': volume,
      };
    }).toList();
  }

  void start({List<SectionConfig>? sections}) {
    if (_isPlaying) stop();
    _sections = sections;
    _sectionIndex = 0;
    if (sections != null && sections.isNotEmpty) {
      _applySectionConfig(sections[0]);
    }
    _isPlaying = true;
    _isPaused = false;
    _tickIndex = 0;
    _firedTickIndex = 0;
    _visualBeatIndex = 0;
    _currentMeasure = 1;
    _pendingMeasureIncrement = false;
    _stopwatch.reset();
    _stopwatch.start();
    _nextBeatMs = 0.0;
    if (_usesNativeTiming) {
      // Await the channel round-trip before starting the Dart timer.
      // result.success() is called on the native side after startBeatThread(),
      // so when this resolves the native beat thread has already fired beat 0
      // (or is within ~2 ms of doing so).  Setting _nextBeatMs=0 then means
      // visual beat 0 fires on the very next poll (~4 ms later), which is
      // within the audio-visual sync tolerance on every device — no
      // hardcoded per-device guess needed.
      _emit(); // show playing state immediately so the UI switches to stop btn
      _native.start(_bpm, _buildNativeTicks()).then((_) {
        if (!_isPlaying) return; // stop() called during round-trip
        // Anchor _nextBeatMs to current elapsed time so that:
        //   (a) visual beat 0 fires right now (no extra 4 ms poll lag), and
        //   (b) every subsequent _nextBeatMs = nowMs + n*intervalMs, keeping
        //       the visual-to-visual gap exactly intervalMs regardless of how
        //       long the channel round-trip took.
        final nowMs = _stopwatch.elapsedMicroseconds / 1000.0;
        _nextBeatMs = nowMs;
        _fireBeat(nowMs);
        _timer = Timer.periodic(const Duration(milliseconds: 4), _poll);
      });
    } else {
      _timer = Timer.periodic(const Duration(milliseconds: 4), _poll);
      _emit();
    }
  }

  void stop() {
    _timer?.cancel();
    _stopwatch.stop();
    if (_usesNativeTiming) {
      _native.stop();
    }
    _isPlaying = false;
    _isPaused = false;
    _tickIndex = 0;
    _firedTickIndex = 0;
    _visualBeatIndex = 0;
    _currentMeasure = 1;
    _pendingMeasureIncrement = false;
    _sections = null;
    _tapTimes.clear();
    _emit();
  }

  void pause() {
    if (!_isPlaying || _isPaused) return;
    _timer?.cancel();
    _stopwatch.stop();
    if (_usesNativeTiming) {
      _native.pause();
    }
    _isPaused = true;
    _emit();
  }

  void resume() {
    if (!_isPaused) return;
    _isPaused = false;
    _stopwatch.start();
    if (_usesNativeTiming) {
      _native.resume();
    }
    _timer = Timer.periodic(const Duration(milliseconds: 4), _poll);
    _emit();
  }

  void setBpm(int bpm) {
    _bpm = bpm.clamp(AppConstants.minBpm, AppConstants.maxBpm);
    if (_usesNativeTiming) {
      _native.setBpm(_bpm);
    }
    _emit();
  }

  void setTimeSignature(MetronomeTimeSignature ts) {
    _timeSignature = ts;
    final subs = ts.availableSubdivisions;
    if (!subs.contains(_subdivision)) _subdivision = subs.first;
    _rebuildPattern();
    _tickIndex = 0;
    _visualBeatIndex = 0;
    if (_isPlaying && !_isPaused) {
      _nextBeatMs = _stopwatch.elapsedMicroseconds / 1000.0;
    }
    if (_isPlaying && (_usesNativeTiming)) {
      _native.updatePattern(_bpm, _buildNativeTicks());
    }
    _emit();
  }

  void setSubdivision(MetronomeSubdivision sub) {
    _subdivision = sub;
    _rebuildPattern();
    _tickIndex = 0;
    _visualBeatIndex = 0;
    if (_isPlaying && !_isPaused) {
      _nextBeatMs = _stopwatch.elapsedMicroseconds / 1000.0;
    }
    if (_isPlaying && (_usesNativeTiming)) {
      _native.updatePattern(_bpm, _buildNativeTicks());
    }
    _emit();
  }

  void setAccentFirstBeat(bool value) {
    _accentFirstBeat = value;
    if (_isPlaying && !_isPaused) {
      _nextBeatMs = _stopwatch.elapsedMicroseconds / 1000.0;
    }
    if (_isPlaying && _usesNativeTiming) {
      _native.updatePattern(_bpm, _buildNativeTicks());
    }
    _emit();
  }

  void tapTempo() {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Gap > 3 s means the user is starting a new tempo tap sequence.
    if (_tapTimes.isNotEmpty && now - _tapTimes.last > 3000) {
      _tapTimes.clear();
    }
    _tapTimes.add(now);
    if (_tapTimes.length > 8) _tapTimes.removeAt(0);
    if (_tapTimes.length >= 2) {
      final intervals = <int>[];
      for (int i = 1; i < _tapTimes.length; i++) {
        intervals.add(_tapTimes[i] - _tapTimes[i - 1]);
      }
      final avg = intervals.reduce((a, b) => a + b) / intervals.length;
      _bpm = (60000 / avg).round().clamp(AppConstants.minBpm, AppConstants.maxBpm);
      _emit();
    }
  }

  int get bpm => _bpm;
  MetronomeTimeSignature get timeSignature => _timeSignature;
  MetronomeSubdivision get subdivision => _subdivision;
  bool get accentFirstBeat => _accentFirstBeat;
  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  int get currentSectionIndex => _sectionIndex;

  // ── Internal tick loop ─────────────────────────────────────────────────────

  // Polled every 4 ms. Fires a beat whenever the wall clock reaches _nextBeatMs.
  // Using a periodic poll instead of a rescheduled single-shot timer eliminates
  // two bugs:
  //   1. "Fast second beat": the old code set _accumulatedMs=0 at start() but
  //      the first callback fired Δ ms later, making the first gap intervalMs-Δ.
  //   2. Jitter accumulation: late single-shot callbacks shortened the next
  //      interval to compensate, compounding under event-loop load.
  void _poll(Timer _) {
    if (!_isPlaying || _isPaused) return;
    final nowMs = _stopwatch.elapsedMicroseconds / 1000.0;
    if (nowMs < _nextBeatMs) return;
    _fireBeat(nowMs);
  }

  void _fireBeat(double nowMs) {
    // Measure increments at the downbeat so the display shows the correct
    // measure number while it is playing.
    if (_pendingMeasureIncrement) {
      _currentMeasure++;
      _pendingMeasureIncrement = false;
      _checkSectionTransition();
      if (!_isPlaying) return;
    }

    final tick = _pattern[_tickIndex];
    final firedIndex = _tickIndex;
    final quarterMs = 60000.0 / _bpm;
    final intervalMs = tick.quarterNoteMultiplier * quarterMs;

    _playTick(tick.level);

    if (tick.level == BeatLevel.downbeat) {
      _visualBeatIndex = 0;
    } else if (tick.level == BeatLevel.beat) {
      _visualBeatIndex++;
    }

    _tickIndex++;
    if (_tickIndex >= _pattern.length) {
      _tickIndex = 0;
      _pendingMeasureIncrement = true;
    }

    _firedTickIndex = firedIndex;
    _nextBeatMs += intervalMs;

    // If the Dart event loop was delayed past the next deadline, fast-forward
    // the tick counter to stay in phase with the native beat thread.
    // The native thread fires every beat regardless — if we just bump the
    // deadline without advancing _tickIndex the visual dots show the wrong beat.
    // On non-native platforms there is no independent audio thread, so simply
    // advancing the deadline is correct.
    if (_usesNativeTiming) {
      while (nowMs >= _nextBeatMs) {
        final skipped = _pattern[_tickIndex];
        if (skipped.level == BeatLevel.downbeat) {
          _visualBeatIndex = 0;
        } else if (skipped.level == BeatLevel.beat) {
          _visualBeatIndex++;
        }
        _nextBeatMs += skipped.quarterNoteMultiplier * (60000.0 / _bpm);
        _tickIndex++;
        if (_tickIndex >= _pattern.length) {
          _tickIndex = 0;
          _pendingMeasureIncrement = true;
        }
      }
    } else {
      if (nowMs >= _nextBeatMs) {
        _nextBeatMs = nowMs + intervalMs;
      }
    }

    _emit(lastFiredLevel: tick.level);
  }

  void _checkSectionTransition() {
    final sections = _sections;
    if (sections == null || sections.isEmpty) return;

    final current = sections[_sectionIndex];
    if (_currentMeasure > current.endMeasure) {
      final nextIndex = _sectionIndex + 1;
      if (nextIndex >= sections.length) {
        stop();
        onPieceComplete?.call();
        return;
      }
      _sectionIndex = nextIndex;
      _applySectionConfig(sections[nextIndex]);
      onSectionChanged?.call(nextIndex);
    }
  }

  void _applySectionConfig(SectionConfig cfg) {
    _bpm = cfg.bpm.clamp(AppConstants.minBpm, AppConstants.maxBpm);
    _timeSignature = cfg.timeSignature;
    _subdivision = cfg.subdivision;
    _accentFirstBeat = cfg.accentFirstBeat;
    _rebuildPattern();
    _tickIndex = 0;
    _visualBeatIndex = 0;
    // Push new pattern to native thread; it resets its tick index atomically.
    if (_usesNativeTiming) {
      _native.updatePattern(_bpm, _buildNativeTicks());
    }
  }

  void _playTick(BeatLevel level) {
    if (!_audioReady) return;
    // On Android/Windows the native beat thread owns audio — skip here.
    if (_usesNativeTiming) return;

    BeatLevel effective = level;
    if (level == BeatLevel.downbeat && !_accentFirstBeat) {
      effective = BeatLevel.beat;
    }
    switch (effective) {
      case BeatLevel.downbeat:
        _downbeat.fire();
      case BeatLevel.beat:
        _beat.fire();
      case BeatLevel.subdivision:
        _sub.fire();
    }
  }

  void _emit({BeatLevel? lastFiredLevel}) {
    if (_ctrl.isClosed) return;
    _ctrl.add(MetronomeState(
      isPlaying: _isPlaying,
      isPaused: _isPaused,
      isAudioReady: _audioReady,
      bpm: _bpm,
      timeSignature: _timeSignature,
      subdivision: _subdivision,
      accentFirstBeat: _accentFirstBeat,
      visualBeatIndex: _visualBeatIndex,
      visualTotalBeats: _visualTotalBeats,
      currentTickIndex: _firedTickIndex,
      totalTicks: _pattern.length,
      currentMeasure: _currentMeasure,
      lastFiredLevel: lastFiredLevel,
    ));
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    stop();
    await _ctrl.close();
    if (_usesNativeTiming) {
      await _native.dispose();
    } else {
      await _downbeat.dispose();
      await _beat.dispose();
      await _sub.dispose();
    }
  }
}
