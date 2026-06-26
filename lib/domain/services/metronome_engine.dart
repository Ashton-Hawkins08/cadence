import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

// ── Audio click pool ──────────────────────────────────────────────────────────

class _ClickPool {
  static const _poolSize = 3;
  final List<AudioPlayer> _players =
      List.generate(_poolSize, (_) => AudioPlayer());
  int _index = 0;
  String? _path;
  bool _ready = false;

  Future<void> init(String path) async {
    _path = path;
    for (final p in _players) {
      await p.setPlayerMode(PlayerMode.lowLatency);
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setSource(DeviceFileSource(path));
    }
    _ready = true;
  }

  void fire({double volume = 1.0}) {
    if (!_ready || _path == null) return;
    final p = _players[_index % _poolSize];
    _index++;
    p.setVolume(volume);
    p.stop();
    p.resume();
  }

  Future<void> dispose() async {
    for (final p in _players) {
      await p.dispose();
    }
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
  double _accumulatedMs = 0;
  Timer? _timer;

  // ── Audio ──────────────────────────────────────────────────────────────────
  bool _audioReady = false;
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

  void _rebuildPattern() {
    _pattern = buildTickPattern(_timeSignature, _subdivision);
    _visualTotalBeats = _visualBeatsFor(_timeSignature, _subdivision);
  }

  // ── Audio init ─────────────────────────────────────────────────────────────

  Future<void> _initAudio() async {
    if (kIsWeb) {
      _audioReady = true;
      _emit();
      return;
    }
    try {
      final dir = await getTemporaryDirectory();
      final d = File('${dir.path}/metro_down.wav');
      final b = File('${dir.path}/metro_beat.wav');
      final s = File('${dir.path}/metro_sub.wav');
      await d.writeAsBytes(WavGenerator.downbeat());
      await b.writeAsBytes(WavGenerator.beat());
      await s.writeAsBytes(WavGenerator.subdivision());
      await _downbeat.init(d.path);
      await _beat.init(b.path);
      await _sub.init(s.path);
      _audioReady = true;
      _emit();
    } catch (_) {
      _audioReady = true;
      _emit();
    }
  }

  // ── Public controls ────────────────────────────────────────────────────────

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
    _accumulatedMs = 0;
    _timer = Timer(Duration.zero, _onTick);
    _emit();
  }

  void stop() {
    _timer?.cancel();
    _stopwatch.stop();
    _isPlaying = false;
    _isPaused = false;
    _tickIndex = 0;
    _firedTickIndex = 0;
    _visualBeatIndex = 0;
    _currentMeasure = 1;
    _pendingMeasureIncrement = false;
    _sections = null;
    _emit();
  }

  void pause() {
    if (!_isPlaying || _isPaused) return;
    _timer?.cancel();
    _stopwatch.stop();
    _isPaused = true;
    _emit();
  }

  void resume() {
    if (!_isPaused) return;
    _isPaused = false;
    _stopwatch.start();
    final now = _stopwatch.elapsedMilliseconds.toDouble();
    final delay = (_accumulatedMs - now).clamp(0.0, 2000.0);
    _timer = Timer(Duration(milliseconds: delay.round()), _onTick);
    _emit();
  }

  void setBpm(int bpm) {
    _bpm = bpm.clamp(AppConstants.minBpm, AppConstants.maxBpm);
    _emit();
  }

  void setTimeSignature(MetronomeTimeSignature ts) {
    _timeSignature = ts;
    final subs = ts.availableSubdivisions;
    if (!subs.contains(_subdivision)) _subdivision = subs.first;
    _rebuildPattern();
    _tickIndex = 0;
    _visualBeatIndex = 0;
    _emit();
  }

  void setSubdivision(MetronomeSubdivision sub) {
    _subdivision = sub;
    _rebuildPattern();
    _tickIndex = 0;
    _visualBeatIndex = 0;
    _emit();
  }

  void setAccentFirstBeat(bool value) {
    _accentFirstBeat = value;
    _emit();
  }

  void tapTempo() {
    final now = DateTime.now().millisecondsSinceEpoch;
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

  void _onTick() {
    if (!_isPlaying || _isPaused) return;

    // Measure increments at the downbeat, not at the end of the previous measure,
    // so the display always shows the correct measure while it's playing.
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
    _emit(lastFiredLevel: tick.level);

    _accumulatedMs += intervalMs;
    final now = _stopwatch.elapsedMilliseconds.toDouble();
    final delay = (_accumulatedMs - now).clamp(0.0, intervalMs * 2.5);
    _timer = Timer(Duration(milliseconds: delay.round()), _onTick);
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
  }

  void _playTick(BeatLevel level) {
    if (!_audioReady) return;
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
        _sub.fire(volume: 0.6);
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
    stop();
    await _ctrl.close();
    await _downbeat.dispose();
    await _beat.dispose();
    await _sub.dispose();
  }
}
