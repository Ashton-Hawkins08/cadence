import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/domain/services/metronome_engine.dart';

export 'package:cadence/domain/services/metronome_engine.dart'
    show MetronomeEngine, MetronomeState, SectionConfig;

// ── Engine provider (singleton, disposed when last subscriber goes away) ──────

final metronomeEngineProvider = Provider<MetronomeEngine>((ref) {
  final engine = MetronomeEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

// ── State stream ──────────────────────────────────────────────────────────────

final metronomeStateProvider = StreamProvider<MetronomeState>((ref) {
  final engine = ref.watch(metronomeEngineProvider);
  return engine.stateStream;
});
