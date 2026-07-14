import 'dart:async';
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cadence/data/database/app_database.dart';
import 'package:cadence/domain/services/auto_backup_coordinator.dart';
import 'package:cadence/domain/services/cloud_sync_service.dart';
import 'package:cadence/presentation/providers/cloud_provider.dart';
import 'package:cadence/presentation/providers/database_provider.dart';

// AutoBackupCoordinator's whole reason to exist is coalescing a burst of
// local writes into ONE backup call after things go quiet, rather than
// hammering Firestore on every keystroke-equivalent database write. That
// coalescing behavior is exactly what these tests pin down, using fake_async
// so the 10-second debounce window doesn't mean a genuinely slow test.

class _CountingSyncService extends CloudSyncService {
  final void Function() onBackup;
  _CountingSyncService({
    required super.db,
    required super.uid,
    required super.firestore,
    required this.onBackup,
  });

  @override
  Future<void> backup() async {
    onBackup();
    await super.backup();
  }
}

void main() {
  test('a burst of writes produces exactly one backup after the debounce window',
      () {
    fakeAsync((async) {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final firestore = FakeFirebaseFirestore();
      var backupCalls = 0;

      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        cloudAvailableProvider.overrideWithValue(true),
        authStateProvider.overrideWith(
            (ref) => Stream.value(MockUser(uid: 'u1') as User)),
        cloudSyncServiceProvider.overrideWithValue(_CountingSyncService(
          db: db,
          uid: 'u1',
          firestore: firestore,
          onBackup: () => backupCalls++,
        )),
      ]);
      addTearDown(container.dispose);

      container.read(autoBackupProvider); // constructs, starts listening
      async.elapse(Duration.zero); // let the stream subscription attach

      db.into(db.categories).insert(
          CategoriesCompanion.insert(name: 'a', createdAt: DateTime.now()));
      async.elapse(const Duration(seconds: 3));
      db.into(db.categories).insert(
          CategoriesCompanion.insert(name: 'b', createdAt: DateTime.now()));
      async.elapse(const Duration(seconds: 3));
      db.into(db.categories).insert(
          CategoriesCompanion.insert(name: 'c', createdAt: DateTime.now()));

      // Still inside the debounce window measured from the LAST write.
      async.elapse(const Duration(seconds: 6));
      expect(backupCalls, 0,
          reason: 'must not back up mid-burst — only once things go quiet');

      // Past the debounce window since the last write.
      async.elapse(const Duration(seconds: 6));
      expect(backupCalls, 1,
          reason: 'three writes 3s apart must coalesce into one backup');
    });
  });

  test('signing out stops further auto-backups', () {
    fakeAsync((async) {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final firestore = FakeFirebaseFirestore();
      var backupCalls = 0;
      final authController = StreamController<User?>();
      addTearDown(authController.close);

      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        cloudAvailableProvider.overrideWithValue(true),
        authStateProvider.overrideWith((ref) => authController.stream),
        cloudSyncServiceProvider.overrideWith((ref) {
          // Mirrors the real provider's null-when-signed-out contract, using
          // whatever the (overridden) authStateProvider currently reports.
          return ref.watch(authStateProvider).valueOrNull == null
              ? null
              : _CountingSyncService(
                  db: db,
                  uid: 'u1',
                  firestore: firestore,
                  onBackup: () => backupCalls++,
                );
        }),
      ]);
      addTearDown(container.dispose);

      container.read(autoBackupProvider);
      authController.add(MockUser(uid: 'u1'));
      async.elapse(Duration.zero);

      db.into(db.categories).insert(
          CategoriesCompanion.insert(name: 'a', createdAt: DateTime.now()));
      async.elapse(Duration.zero);
      authController.add(null); // signed out mid-debounce
      async.elapse(AutoBackupCoordinator.debounceDelay + const Duration(seconds: 1));

      expect(backupCalls, 0,
          reason: 'signing out mid-debounce must cancel the pending backup');
    });
  });
}
