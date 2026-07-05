import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/domain/services/metronome_engine.dart';
import 'package:cadence/domain/services/audit_log_service.dart';
import 'package:cadence/presentation/providers/database_provider.dart';

export 'package:cadence/domain/services/metronome_engine.dart'
    show MetronomeEngine, MetronomeState, SectionConfig;

// ── Engine provider (singleton, disposed when last subscriber goes away) ──────

final metronomeEngineProvider = Provider<MetronomeEngine>((ref) {
  final engine = MetronomeEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

// ── Tamper-evident audit log ──────────────────────────────────────────────────

final auditLogServiceProvider = Provider<AuditLogService>((ref) {
  return AuditLogService(ref.watch(databaseProvider));
});

// Records every play→stop span into the hash-chained audit ledger. Kept alive
// by metronomeStateProvider below, which every metronome screen watches — so
// the recorder always exists before a session can start.
final auditRecorderProvider = Provider<AuditRecorder>((ref) {
  final recorder = AuditRecorder(
    ref.watch(metronomeEngineProvider),
    ref.watch(auditLogServiceProvider),
  );
  ref.onDispose(recorder.dispose);
  return recorder;
});

// ── State stream ──────────────────────────────────────────────────────────────

final metronomeStateProvider = StreamProvider<MetronomeState>((ref) {
  // Ensure the audit recorder is subscribed before any beat can fire.
  ref.watch(auditRecorderProvider);
  final engine = ref.watch(metronomeEngineProvider);
  return engine.stateStream;
});
