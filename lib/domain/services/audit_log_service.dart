import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:cadence/data/database/app_database.dart';
import 'metronome_engine.dart';

// ── Tamper-evident practice audit log ─────────────────────────────────────────
//
// Every real metronome session is recorded automatically into a SHA-256 hash
// chain (see AuditSessions in app_database.dart). Two components live here:
//
//  • AuditLogService — writes chain entries and verifies chain integrity.
//  • AuditRecorder   — observes MetronomeEngine's state stream and turns
//    play→stop spans into audit entries. It never touches the audio path;
//    it is a pure listener.
//
// Threat model (be honest about it): a local-only ledger cannot stop someone
// with a hex editor from rebuilding the entire chain. What it does stop is
// casual falsification — editing a duration, back-dating a session, deleting
// a bad week — because any single-row change breaks every subsequent hash
// and the report prints VERIFIED/BROKEN accordingly.

class ChainVerification {
  final bool valid;
  final int totalEntries;

  /// Row id of the first broken link (null when valid).
  final int? firstBrokenId;
  const ChainVerification({
    required this.valid,
    required this.totalEntries,
    this.firstBrokenId,
  });
}

class AuditLogService {
  final AppDatabase _db;
  const AuditLogService(this._db);

  static const _genesis = 'GENESIS';

  /// Canonical payload string — field order is FROZEN. Changing it would
  /// invalidate every previously recorded chain.
  static String canonicalPayload({
    required DateTime startedAt,
    required DateTime endedAt,
    required int seconds,
    required int bpmLow,
    required int bpmHigh,
    required int bpmLast,
    required String timeSignature,
    required String subdivision,
    required String mode,
    required String prevHash,
  }) {
    return [
      startedAt.toUtc().millisecondsSinceEpoch,
      endedAt.toUtc().millisecondsSinceEpoch,
      seconds,
      bpmLow,
      bpmHigh,
      bpmLast,
      timeSignature,
      subdivision,
      mode,
      prevHash,
    ].join('|');
  }

  static String _hash(String payload) =>
      sha256.convert(utf8.encode(payload)).toString();

  Future<void> recordSession({
    required DateTime startedAt,
    required DateTime endedAt,
    required int seconds,
    required int bpmLow,
    required int bpmHigh,
    required int bpmLast,
    required String timeSignature,
    required String subdivision,
    required String mode,
  }) async {
    // Serialize chain appends: a transaction guarantees the prevHash we read
    // is still the tip when we insert.
    await _db.transaction(() async {
      final last = await (_db.select(_db.auditSessions)
            ..orderBy([(t) => OrderingTerm.desc(t.id)])
            ..limit(1))
          .getSingleOrNull();
      final prevHash = last?.entryHash ?? _genesis;

      final payload = canonicalPayload(
        startedAt: startedAt,
        endedAt: endedAt,
        seconds: seconds,
        bpmLow: bpmLow,
        bpmHigh: bpmHigh,
        bpmLast: bpmLast,
        timeSignature: timeSignature,
        subdivision: subdivision,
        mode: mode,
        prevHash: prevHash,
      );

      await _db.into(_db.auditSessions).insert(AuditSessionsCompanion.insert(
            startedAt: startedAt,
            endedAt: endedAt,
            seconds: seconds,
            bpmLow: bpmLow,
            bpmHigh: bpmHigh,
            bpmLast: bpmLast,
            timeSignature: timeSignature,
            subdivision: subdivision,
            mode: mode,
            prevHash: prevHash,
            entryHash: _hash(payload),
          ));
    });
  }

  /// Recomputes the whole chain from genesis. O(n) — trivially fast for the
  /// row counts a practice ledger reaches.
  Future<ChainVerification> verifyChain() async {
    final rows = await (_db.select(_db.auditSessions)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();

    var expectedPrev = _genesis;
    for (final row in rows) {
      if (row.prevHash != expectedPrev) {
        return ChainVerification(
            valid: false, totalEntries: rows.length, firstBrokenId: row.id);
      }
      final payload = canonicalPayload(
        startedAt: row.startedAt,
        endedAt: row.endedAt,
        seconds: row.seconds,
        bpmLow: row.bpmLow,
        bpmHigh: row.bpmHigh,
        bpmLast: row.bpmLast,
        timeSignature: row.timeSignature,
        subdivision: row.subdivision,
        mode: row.mode,
        prevHash: row.prevHash,
      );
      if (_hash(payload) != row.entryHash) {
        return ChainVerification(
            valid: false, totalEntries: rows.length, firstBrokenId: row.id);
      }
      expectedPrev = row.entryHash;
    }
    return ChainVerification(valid: true, totalEntries: rows.length);
  }

  Stream<List<AuditSession>> watchSessions({int limit = 200}) {
    return (_db.select(_db.auditSessions)
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(limit))
        .watch();
  }

  /// Plain-text report a director can scan (or paste into email/print).
  Future<String> buildReport() async {
    final rows = await (_db.select(_db.auditSessions)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    final check = await verifyChain();

    final totalSeconds = rows.fold<int>(0, (a, r) => a + r.seconds);
    final days = rows.map((r) {
      final d = r.startedAt.toLocal();
      return '${d.year}-${d.month}-${d.day}';
    }).toSet();

    final b = StringBuffer()
      ..writeln('CADENCE PRACTICE AUDIT REPORT')
      ..writeln('Generated: ${DateTime.now().toLocal()}')
      ..writeln('Integrity: '
          '${check.valid ? "VERIFIED (unbroken hash chain)" : "BROKEN at entry #${check.firstBrokenId}"}')
      ..writeln('Sessions: ${rows.length}   '
          'Total: ${(totalSeconds / 60).round()} min   '
          'Distinct days: ${days.length}')
      ..writeln('Chain tip: ${rows.isEmpty ? "—" : rows.last.entryHash.substring(0, 16)}…')
      ..writeln('─' * 46);
    for (final r in rows.reversed) {
      final start = r.startedAt.toLocal();
      final date =
          '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
      final time =
          '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
      final min = (r.seconds / 60).toStringAsFixed(1);
      b.writeln('#${r.id}  $date $time  ${min}m  '
          '♩${r.bpmLow == r.bpmHigh ? r.bpmLow : "${r.bpmLow}–${r.bpmHigh}"}  '
          '${r.timeSignature}  ${r.mode}  ${r.entryHash.substring(0, 8)}');
    }
    return b.toString();
  }
}

// ── Session recorder ──────────────────────────────────────────────────────────

class AuditRecorder {
  final MetronomeEngine _engine;
  final AuditLogService _log;
  StreamSubscription<MetronomeState>? _sub;

  // In-flight session accumulation
  DateTime? _startedAt;
  int _bpmLow = 0, _bpmHigh = 0, _bpmLast = 0;
  String _timeSignature = '', _subdivision = '';
  bool _sawCognitive = false;
  bool _sawRandomizer = false;
  bool _sawPiece = false;

  /// Sessions shorter than this are discarded — they're sound checks and
  /// mis-taps, not practice, and they'd bury the real entries in noise.
  static const minSessionSeconds = 10;

  /// Set by the UI while blind-randomizer mode is on, so sessions can be
  /// attributed to that mode. (The engine doesn't know about the randomizer
  /// by design — it only ever sees setBpm calls.)
  bool randomizerActive = false;

  AuditRecorder(this._engine, this._log) {
    _sub = _engine.stateStream.listen(_onState);
  }

  void _onState(MetronomeState s) {
    if (s.isPlaying && _startedAt == null) {
      // Session opens
      _startedAt = DateTime.now();
      _bpmLow = s.bpm;
      _bpmHigh = s.bpm;
      _bpmLast = s.bpm;
      _timeSignature = s.timeSignature.name;
      _subdivision = s.subdivision.name;
      _sawCognitive = s.cognitiveBreakActive;
      _sawRandomizer = randomizerActive;
      _sawPiece = _engine.isPieceMode;
    } else if (s.isPlaying) {
      // Session continues — track the tempo envelope
      if (s.bpm < _bpmLow) _bpmLow = s.bpm;
      if (s.bpm > _bpmHigh) _bpmHigh = s.bpm;
      _bpmLast = s.bpm;
      _timeSignature = s.timeSignature.name;
      _subdivision = s.subdivision.name;
      _sawCognitive = _sawCognitive || s.cognitiveBreakActive;
      _sawRandomizer = _sawRandomizer || randomizerActive;
      _sawPiece = _sawPiece || _engine.isPieceMode;
    } else if (!s.isPlaying && _startedAt != null) {
      _closeSession();
    }
  }

  void _closeSession() {
    final startedAt = _startedAt!;
    _startedAt = null;
    final endedAt = DateTime.now();
    final seconds = endedAt.difference(startedAt).inSeconds;
    if (seconds < minSessionSeconds) return;

    final mode = _sawPiece
        ? 'piece'
        : _sawCognitive
            ? 'cognitive'
            : _sawRandomizer
                ? 'randomizer'
                : 'standard';

    // Fire-and-forget: recording must never block or throw into the
    // engine's state stream.
    unawaited(_log
        .recordSession(
          startedAt: startedAt,
          endedAt: endedAt,
          seconds: seconds,
          bpmLow: _bpmLow,
          bpmHigh: _bpmHigh,
          bpmLast: _bpmLast,
          timeSignature: _timeSignature,
          subdivision: _subdivision,
          mode: mode,
        )
        .catchError((_) {}));
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
