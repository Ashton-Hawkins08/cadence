import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cadence/data/database/app_database.dart';
import 'package:cadence/domain/services/cloud_sync_service.dart';

// The entire point of CloudSyncService is correctness across devices with
// DIFFERENT local auto-increment ids. So "device A" and "device B" here are
// two separate in-memory databases sharing one fake Firestore — if a test
// merely round-tripped through ONE database, matching local ids could hide
// a real foreign-key bug (push and pull would agree by coincidence).

AppDatabase _freshDb() => AppDatabase(NativeDatabase.memory());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const uid = 'test-uid';

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('exercise, bpm log, and piece section survive a cross-device round trip '
      'with correctly remapped foreign keys', () async {
    final deviceA = _freshDb();
    final firestore = FakeFirebaseFirestore();

    final categoryId = await deviceA.into(deviceA.categories).insert(
        CategoriesCompanion.insert(name: 'Rudiments', createdAt: DateTime.now()));
    final exerciseId = await deviceA.into(deviceA.exercises).insert(
        ExercisesCompanion.insert(name: 'Paradiddles', categoryId: Value(categoryId)));
    await deviceA.into(deviceA.bpmLogs).insert(BpmLogsCompanion.insert(
        exerciseId: exerciseId, bpm: 140, loggedAt: DateTime.now()));
    final pieceId = await deviceA.into(deviceA.metronomePieces).insert(
        MetronomePiecesCompanion.insert(
            title: 'Concert Piece',
            createdAt: DateTime.now(),
            modifiedAt: DateTime.now(),
            exerciseId: Value(exerciseId)));
    await deviceA.into(deviceA.pieceSections).insert(PieceSectionsCompanion.insert(
        pieceId: pieceId,
        sortOrder: 0,
        startMeasure: 1,
        endMeasure: 8,
        bpm: 90,
        timeSignature: 'sig4_4',
        subdivision: 'quarter'));

    // Force device A's local ids to NOT coincidentally match device B's —
    // otherwise a broken remap that just copies the raw int could pass.
    final deviceB = _freshDb();
    for (var i = 0; i < 5; i++) {
      await deviceB.into(deviceB.categories).insert(
          CategoriesCompanion.insert(name: 'padding $i', createdAt: DateTime.now()));
    }

    await CloudSyncService(db: deviceA, uid: uid, firestore: firestore).backup();
    await CloudSyncService(db: deviceB, uid: uid, firestore: firestore).restore();

    final bCategory = await (deviceB.select(deviceB.categories)
          ..where((t) => t.name.equals('Rudiments')))
        .getSingle();
    final bExercise = await (deviceB.select(deviceB.exercises)
          ..where((t) => t.name.equals('Paradiddles')))
        .getSingle();
    expect(bExercise.categoryId, bCategory.id,
        reason: "the exercise's categoryId must point at device B's OWN "
            'local id for the category, not device A\'s');
    expect(bExercise.categoryId, isNot(categoryId),
        reason: 'a passing test must not be hiding behind coincidentally '
            'identical ids between the two devices');

    final bBpmLog = await deviceB.select(deviceB.bpmLogs).getSingle();
    expect(bBpmLog.exerciseId, bExercise.id);
    expect(bBpmLog.bpm, 140);

    final bPiece = await deviceB.select(deviceB.metronomePieces).getSingle();
    expect(bPiece.exerciseId, bExercise.id);
    final bSection = await deviceB.select(deviceB.pieceSections).getSingle();
    expect(bSection.pieceId, bPiece.id);
    expect(bSection.endMeasure, 8);

    await deviceA.close();
    await deviceB.close();
  });

  test('restore never deletes a local row absent from the cloud', () async {
    final device = _freshDb();
    final firestore = FakeFirebaseFirestore();
    await device.into(device.categories).insert(
        CategoriesCompanion.insert(name: 'Only local', createdAt: DateTime.now()));

    await CloudSyncService(db: device, uid: uid, firestore: firestore).restore();

    final rows = await device.select(device.categories).get();
    expect(rows, hasLength(1), reason: 'an empty cloud backup must not wipe local data');
    await device.close();
  });

  test('restore is idempotent — running it twice does not duplicate rows',
      () async {
    final deviceA = _freshDb();
    final firestore = FakeFirebaseFirestore();
    await deviceA.into(deviceA.categories).insert(
        CategoriesCompanion.insert(name: 'Once', createdAt: DateTime.now()));
    await CloudSyncService(db: deviceA, uid: uid, firestore: firestore).backup();

    final deviceB = _freshDb();
    final sync = CloudSyncService(db: deviceB, uid: uid, firestore: firestore);
    await sync.restore();
    await sync.restore();

    final rows = await deviceB.select(deviceB.categories).get();
    expect(rows, hasLength(1));
    await deviceA.close();
    await deviceB.close();
  });

  test('a locally-modified row beats an older cloud copy (last-write-wins)',
      () async {
    final deviceA = _freshDb();
    final firestore = FakeFirebaseFirestore();
    final id = await deviceA.into(deviceA.categories).insert(
        CategoriesCompanion.insert(name: 'Old name', createdAt: DateTime.now()));
    await CloudSyncService(db: deviceA, uid: uid, firestore: firestore).backup();

    // Device B already has the SAME row (same syncId) but edited more
    // recently than the cloud copy.
    final deviceB = _freshDb();
    await CloudSyncService(db: deviceB, uid: uid, firestore: firestore).restore();
    final syncId = (await deviceB.select(deviceB.categories).getSingle()).syncId;
    await (deviceB.update(deviceB.categories)..where((t) => t.id.equals(id)))
        .write(CategoriesCompanion(
      name: const Value('New name'),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch + 100000),
    ));

    await CloudSyncService(db: deviceB, uid: uid, firestore: firestore).restore();

    final row = await (deviceB.select(deviceB.categories)
          ..where((t) => t.syncId.equals(syncId)))
        .getSingle();
    expect(row.name, 'New name',
        reason: 'the newer local edit must survive a restore of the older cloud copy');

    await deviceA.close();
    await deviceB.close();
  });

  test('backup propagates a local deletion as a cloud delete', () async {
    final deviceA = _freshDb();
    final firestore = FakeFirebaseFirestore();
    final id = await deviceA.into(deviceA.categories).insert(
        CategoriesCompanion.insert(name: 'Temp', createdAt: DateTime.now()));
    final syncId =
        (await (deviceA.select(deviceA.categories)..where((t) => t.id.equals(id)))
                .getSingle())
            .syncId;
    await CloudSyncService(db: deviceA, uid: uid, firestore: firestore).backup();

    await (deviceA.delete(deviceA.categories)..where((t) => t.id.equals(id))).go();
    await deviceA.into(deviceA.syncTombstones).insert(
        SyncTombstonesCompanion.insert(targetTable: 'categories', rowSyncId: syncId));
    await CloudSyncService(db: deviceA, uid: uid, firestore: firestore).backup();

    final remaining = await deviceA.select(deviceA.syncTombstones).get();
    expect(remaining, isEmpty,
        reason: 'a pushed tombstone must be cleared so it is not re-sent forever');

    final deviceB = _freshDb();
    await CloudSyncService(db: deviceB, uid: uid, firestore: firestore).restore();
    final bRows = await deviceB.select(deviceB.categories).get();
    expect(bRows, isEmpty,
        reason: 'a device restoring fresh must not receive the deleted row');

    await deviceA.close();
    await deviceB.close();
  });

  test('backup and restore carry the profile (name/instrument) to a fresh device',
      () async {
    SharedPreferences.setMockInitialValues({
      'flutter.first_name': 'Ashton',
      'flutter.instrument': 'Snare',
    });
    final deviceA = _freshDb();
    final firestore = FakeFirebaseFirestore();
    await CloudSyncService(db: deviceA, uid: uid, firestore: firestore).backup();

    // Simulate a genuinely fresh device: no local profile yet.
    SharedPreferences.setMockInitialValues({});
    final deviceB = _freshDb();
    await CloudSyncService(db: deviceB, uid: uid, firestore: firestore).restore();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('first_name'), 'Ashton');
    expect(prefs.getString('instrument'), 'Snare');

    await deviceA.close();
    await deviceB.close();
  });

  test('restore never overwrites a profile value already set on this device',
      () async {
    SharedPreferences.setMockInitialValues({
      'flutter.first_name': 'CloudName',
      'flutter.instrument': 'Trumpet',
    });
    final deviceA = _freshDb();
    final firestore = FakeFirebaseFirestore();
    await CloudSyncService(db: deviceA, uid: uid, firestore: firestore).backup();

    SharedPreferences.setMockInitialValues({'flutter.first_name': 'LocalName'});
    final deviceB = _freshDb();
    await CloudSyncService(db: deviceB, uid: uid, firestore: firestore).restore();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('first_name'), 'LocalName',
        reason: 'an existing local name must never be clobbered by restore');
    expect(prefs.getString('instrument'), 'Trumpet',
        reason: 'a blank local field should still be filled in from the cloud');

    await deviceA.close();
    await deviceB.close();
  });
}
