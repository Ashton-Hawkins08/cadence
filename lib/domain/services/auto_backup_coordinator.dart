import 'dart:async';
import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/presentation/providers/cloud_provider.dart';
import 'package:cadence/presentation/providers/database_provider.dart';

/// "Constant backup": while signed in, automatically pushes a backup a
/// short while after the local database goes quiet — no Back Up Now tap
/// required.
///
/// Listens to Drift's own tableUpdates() stream (scoped to the tables
/// CloudSyncService actually syncs — see AppDatabase.cloudSyncedTables)
/// rather than hooking every repository's write methods individually: that
/// approach doesn't need touching ~30 call sites across 5 repositories, and
/// can't silently miss one the way the tombstone wiring almost did.
///
/// Deliberately debounced, not "backup on every write": a single practice
/// session can fire off a dozen writes in quick succession (BPM logs,
/// exercise stat bumps, notes) — backing up after each one would be
/// wasteful network/battery/Firestore-cost churn for no benefit, since the
/// user is still actively changing things. Waiting for a pause coalesces a
/// whole burst of activity into one push.
class AutoBackupCoordinator {
  final Ref ref;
  Timer? _debounce;
  StreamSubscription<void>? _dbSub;
  bool _signedIn = false;

  static const debounceDelay = Duration(seconds: 10);

  AutoBackupCoordinator(this.ref) {
    ref.listen(authStateProvider, (previous, next) {
      final signedIn = next.valueOrNull != null;
      if (signedIn != _signedIn) {
        _signedIn = signedIn;
        _restart();
      }
    }, fireImmediately: true);
  }

  void _restart() {
    _dbSub?.cancel();
    _debounce?.cancel();
    _debounce = null;
    if (!_signedIn) return; // cloud is optional — no account, no auto-push

    final db = ref.read(databaseProvider);
    _dbSub = db
        .tableUpdates(TableUpdateQuery.onAllTables(db.cloudSyncedTables))
        .listen((_) {
      _debounce?.cancel();
      _debounce = Timer(debounceDelay, _runBackup);
    });
  }

  Future<void> _runBackup() async {
    final sync = ref.read(cloudSyncServiceProvider);
    if (sync == null) return; // signed out mid-debounce
    try {
      await sync.backup();
    } catch (_) {
      // Offline, etc. Not a dead end: the next local edit re-arms the
      // timer, so this retries naturally on the next qualifying change
      // rather than needing its own retry/backoff machinery.
    }
  }

  void dispose() {
    _dbSub?.cancel();
    _debounce?.cancel();
  }
}

// Constructed once and kept alive for the app's lifetime by being watched
// in _AppRoot (app.dart) — a plain (non-autoDispose) Provider caches its
// value once built, so watching it repeatedly does not restart the
// coordinator on every rebuild.
final autoBackupProvider = Provider<AutoBackupCoordinator?>((ref) {
  if (!ref.watch(cloudAvailableProvider)) return null;
  final coordinator = AutoBackupCoordinator(ref);
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
