import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' show Value;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cadence/data/database/app_database.dart';

/// Firestore-backed backup and restore for Cadence's core practice-tracking
/// data.
///
/// NOT included yet: the sheet-music vault (score folders/pages/page-turns/
/// annotations). Those rows reference image FILES on disk — syncing just the
/// database rows without the images would leave folders full of broken image
/// links on a fresh device, which is worse than not syncing them at all.
/// Real sheet-music sync needs Firebase Storage for the images themselves;
/// that's a deliberately separate follow-up.
///
/// The genuinely hard part of any two-device sync lives here: local tables
/// use SQLite auto-increment integer ids for foreign keys, and those ids are
/// NOT the same across devices — each device assigns its own. Every row's
/// stable, global identity is its `syncId` (schema v9). So:
///   • PUSH translates every foreign-key int to the referenced row's syncId
///     before writing to Firestore.
///   • PULL translates back: after a parent table is restored, its
///     syncId -> (this device's local id) map resolves every child row's FK.
/// This is why restore walks tables in dependency order (parents first) and
/// why backup reads every table up front before writing anything.
class CloudSyncService {
  final AppDatabase db;
  final String uid;
  final FirebaseFirestore _firestore;

  CloudSyncService({
    required this.db,
    required this.uid,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _firestore.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _col(String table) =>
      _userDoc.collection(table);

  // ── Local sync bookkeeping ─────────────────────────────────────────────────
  //
  // Timestamps of the last successful backup/restore, so Settings can show
  // "Last backed up 2 minutes ago" without a network round-trip just to
  // render that line. Uses the SyncState key-value table (schema v9).

  static const keyLastBackupAt = 'lastBackupAt';
  static const keyLastRestoreAt = 'lastRestoreAt';

  Future<DateTime?> lastBackupAt() => _readTimestamp(keyLastBackupAt);
  Future<DateTime?> lastRestoreAt() => _readTimestamp(keyLastRestoreAt);

  Future<DateTime?> _readTimestamp(String key) async {
    final row = await (db.select(db.syncState)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    if (row == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(int.parse(row.value));
  }

  Future<void> _writeTimestamp(String key, DateTime value) {
    return db.into(db.syncState).insertOnConflictUpdate(
          SyncStateCompanion.insert(
              key: key,
              value: value.millisecondsSinceEpoch.toString()),
        );
  }

  // ── Backup (push) ─────────────────────────────────────────────────────────

  Future<void> backup() async {
    final categories = await db.select(db.categories).get();
    final bundles = await db.select(db.archivedCategoryBundles).get();
    final events = await db.select(db.calendarEvents).get();
    final reminders = await db.select(db.eventReminders).get();
    final exercises = await db.select(db.exercises).get();
    final bpmLogs = await db.select(db.bpmLogs).get();
    final exerciseNotes = await db.select(db.exerciseNotes).get();
    final categoryNotes = await db.select(db.categoryNotes).get();
    final historyEntries = await db.select(db.historyEntries).get();
    final pieces = await db.select(db.metronomePieces).get();
    final sections = await db.select(db.pieceSections).get();

    final categoryOf = {for (final c in categories) c.id: c.syncId};
    final bundleOf = {for (final b in bundles) b.id: b.syncId};
    final eventOf = {for (final e in events) e.id: e.syncId};
    final exerciseOf = {for (final e in exercises) e.id: e.syncId};
    final pieceOf = {for (final p in pieces) p.id: p.syncId};

    final writer = _BatchWriter(_firestore);

    for (final c in categories) {
      writer.set(_col('categories').doc(c.syncId), {
        'syncId': c.syncId,
        'updatedAt': c.updatedAt,
        'name': c.name,
        'createdAt': c.createdAt.millisecondsSinceEpoch,
      });
    }
    for (final b in bundles) {
      writer.set(_col('archived_category_bundles').doc(b.syncId), {
        'syncId': b.syncId,
        'updatedAt': b.updatedAt,
        'name': b.name,
        'archivedAt': b.archivedAt.millisecondsSinceEpoch,
      });
    }
    for (final e in events) {
      writer.set(_col('calendar_events').doc(e.syncId), {
        'syncId': e.syncId,
        'updatedAt': e.updatedAt,
        'title': e.title,
        'notes': e.notes,
        'startDate': e.startDate.millisecondsSinceEpoch,
        'endDate': e.endDate.millisecondsSinceEpoch,
        'colorValue': e.colorValue,
        'createdAt': e.createdAt.millisecondsSinceEpoch,
      });
    }
    for (final r in reminders) {
      final parent = eventOf[r.eventId];
      if (parent == null) continue; // orphaned row — nothing to link to
      writer.set(_col('event_reminders').doc(r.syncId), {
        'syncId': r.syncId,
        'updatedAt': r.updatedAt,
        'eventSyncId': parent,
        'daysBefore': r.daysBefore,
        'customDate': r.customDate?.millisecondsSinceEpoch,
      });
    }
    for (final e in exercises) {
      writer.set(_col('exercises').doc(e.syncId), {
        'syncId': e.syncId,
        'updatedAt': e.updatedAt,
        'name': e.name,
        'categorySyncId':
            e.categoryId != null ? categoryOf[e.categoryId] : null,
        'timesPracticed': e.timesPracticed,
        'totalMinutes': e.totalMinutes,
        'highestBpm': e.highestBpm,
        'lastBpm': e.lastBpm,
        'lastPracticed': e.lastPracticed?.millisecondsSinceEpoch,
        'reminderDays': e.reminderDays,
        'goalBpm': e.goalBpm,
        'initialBpm': e.initialBpm,
        'isArchived': e.isArchived,
        'archivedIndividually': e.archivedIndividually,
        'archivedBundleSyncId': e.archivedCategoryBundleId != null
            ? bundleOf[e.archivedCategoryBundleId]
            : null,
      });
    }
    for (final l in bpmLogs) {
      final parent = exerciseOf[l.exerciseId];
      if (parent == null) continue;
      writer.set(_col('bpm_logs').doc(l.syncId), {
        'syncId': l.syncId,
        'updatedAt': l.updatedAt,
        'exerciseSyncId': parent,
        'bpm': l.bpm,
        'loggedAt': l.loggedAt.millisecondsSinceEpoch,
      });
    }
    for (final n in exerciseNotes) {
      final parent = exerciseOf[n.exerciseId];
      if (parent == null) continue;
      writer.set(_col('exercise_notes').doc(n.syncId), {
        'syncId': n.syncId,
        'updatedAt': n.updatedAt,
        'exerciseSyncId': parent,
        'noteText': n.noteText,
        'createdAt': n.createdAt.millisecondsSinceEpoch,
      });
    }
    for (final n in categoryNotes) {
      final parent = categoryOf[n.categoryId];
      if (parent == null) continue;
      writer.set(_col('category_notes').doc(n.syncId), {
        'syncId': n.syncId,
        'updatedAt': n.updatedAt,
        'categorySyncId': parent,
        'noteText': n.noteText,
        'createdAt': n.createdAt.millisecondsSinceEpoch,
      });
    }
    for (final h in historyEntries) {
      writer.set(_col('history_entries').doc(h.syncId), {
        'syncId': h.syncId,
        'updatedAt': h.updatedAt,
        'exerciseSyncId':
            h.exerciseId != null ? exerciseOf[h.exerciseId] : null,
        'exerciseName': h.exerciseName,
        'date': h.date.millisecondsSinceEpoch,
        'minutes': h.minutes,
        'bpm': h.bpm,
        'note': h.note,
      });
    }
    for (final p in pieces) {
      writer.set(_col('metronome_pieces').doc(p.syncId), {
        'syncId': p.syncId,
        'updatedAt': p.updatedAt,
        'title': p.title,
        'createdAt': p.createdAt.millisecondsSinceEpoch,
        'modifiedAt': p.modifiedAt.millisecondsSinceEpoch,
        'isArchived': p.isArchived,
        'exerciseSyncId':
            p.exerciseId != null ? exerciseOf[p.exerciseId] : null,
      });
    }
    for (final s in sections) {
      final parent = pieceOf[s.pieceId];
      if (parent == null) continue;
      writer.set(_col('piece_sections').doc(s.syncId), {
        'syncId': s.syncId,
        'updatedAt': s.updatedAt,
        'pieceSyncId': parent,
        'sortOrder': s.sortOrder,
        'startMeasure': s.startMeasure,
        'endMeasure': s.endMeasure,
        'bpm': s.bpm,
        'timeSignature': s.timeSignature,
        'subdivision': s.subdivision,
        'accentFirstBeat': s.accentFirstBeat,
      });
    }

    // Propagate pending deletions, then clear the tombstones just pushed —
    // they're now reflected in the cloud, no need to keep re-pushing them.
    final tombstones = await db.select(db.syncTombstones).get();
    final pushedTombstoneIds = <int>[];
    for (final t in tombstones) {
      if (_syncedTombstoneTables.contains(t.targetTable)) {
        writer.delete(_col(t.targetTable).doc(t.rowSyncId));
        pushedTombstoneIds.add(t.id);
      }
    }

    await writer.commit();

    if (pushedTombstoneIds.isNotEmpty) {
      await (db.delete(db.syncTombstones)
            ..where((t) => t.id.isIn(pushedTombstoneIds)))
          .go();
    }

    // Profile fields too, so signing into an existing account on a brand-new
    // device (no local settings yet) has something to restore.
    final prefs = await SharedPreferences.getInstance();
    await _userDoc.set({
      'profile': {
        'firstName': prefs.getString('first_name') ?? '',
        'lastName': prefs.getString('last_name') ?? '',
        'instrument': prefs.getString('instrument') ?? '',
      },
      'lastBackupAt': DateTime.now().millisecondsSinceEpoch,
    }, SetOptions(merge: true));

    await _writeTimestamp(keyLastBackupAt, DateTime.now());
  }

  static const _syncedTombstoneTables = {
    'categories',
    'archived_category_bundles',
    'calendar_events',
    'event_reminders',
    'exercises',
    'bpm_logs',
    'exercise_notes',
    'category_notes',
    'history_entries',
    'metronome_pieces',
    'piece_sections',
  };

  // ── Restore (pull) ────────────────────────────────────────────────────────
  //
  // Walks tables in dependency order (parents before children), upserting by
  // syncId with last-write-wins on updatedAt. Never deletes a local row that
  // has no cloud counterpart — "Restore" merges in what the cloud has; it
  // must never be how you lose data made since your last backup.

  Future<int> restore() async {
    var total = 0;

    final categoryLocal = <String, int>{};
    for (final doc in (await _col('categories').get()).docs) {
      final d = doc.data();
      final syncId = d['syncId'] as String;
      final existing = await (db.select(db.categories)
            ..where((t) => t.syncId.equals(syncId)))
          .getSingleOrNull();
      final remoteUpdatedAt = d['updatedAt'] as int;
      final createdAt =
          DateTime.fromMillisecondsSinceEpoch(d['createdAt'] as int);
      if (existing == null) {
        final id = await db.into(db.categories).insert(CategoriesCompanion(
              syncId: Value(syncId),
              updatedAt: Value(remoteUpdatedAt),
              name: Value(d['name'] as String),
              createdAt: Value(createdAt),
            ));
        categoryLocal[syncId] = id;
      } else {
        categoryLocal[syncId] = existing.id;
        if (remoteUpdatedAt > existing.updatedAt) {
          await (db.update(db.categories)
                ..where((t) => t.id.equals(existing.id)))
              .write(CategoriesCompanion(
            updatedAt: Value(remoteUpdatedAt),
            name: Value(d['name'] as String),
            createdAt: Value(createdAt),
          ));
        }
      }
      total++;
    }

    final bundleLocal = <String, int>{};
    for (final doc in (await _col('archived_category_bundles').get()).docs) {
      final d = doc.data();
      final syncId = d['syncId'] as String;
      final existing = await (db.select(db.archivedCategoryBundles)
            ..where((t) => t.syncId.equals(syncId)))
          .getSingleOrNull();
      final remoteUpdatedAt = d['updatedAt'] as int;
      final archivedAt =
          DateTime.fromMillisecondsSinceEpoch(d['archivedAt'] as int);
      if (existing == null) {
        final id = await db
            .into(db.archivedCategoryBundles)
            .insert(ArchivedCategoryBundlesCompanion(
              syncId: Value(syncId),
              updatedAt: Value(remoteUpdatedAt),
              name: Value(d['name'] as String),
              archivedAt: Value(archivedAt),
            ));
        bundleLocal[syncId] = id;
      } else {
        bundleLocal[syncId] = existing.id;
        if (remoteUpdatedAt > existing.updatedAt) {
          await (db.update(db.archivedCategoryBundles)
                ..where((t) => t.id.equals(existing.id)))
              .write(ArchivedCategoryBundlesCompanion(
            updatedAt: Value(remoteUpdatedAt),
            name: Value(d['name'] as String),
            archivedAt: Value(archivedAt),
          ));
        }
      }
      total++;
    }

    final eventLocal = <String, int>{};
    for (final doc in (await _col('calendar_events').get()).docs) {
      final d = doc.data();
      final syncId = d['syncId'] as String;
      final existing = await (db.select(db.calendarEvents)
            ..where((t) => t.syncId.equals(syncId)))
          .getSingleOrNull();
      final remoteUpdatedAt = d['updatedAt'] as int;
      final companionFields = CalendarEventsCompanion(
        updatedAt: Value(remoteUpdatedAt),
        title: Value(d['title'] as String),
        notes: Value(d['notes'] as String),
        startDate: Value(
            DateTime.fromMillisecondsSinceEpoch(d['startDate'] as int)),
        endDate:
            Value(DateTime.fromMillisecondsSinceEpoch(d['endDate'] as int)),
        colorValue: Value(d['colorValue'] as int?),
        createdAt: Value(
            DateTime.fromMillisecondsSinceEpoch(d['createdAt'] as int)),
      );
      if (existing == null) {
        final id = await db.into(db.calendarEvents).insert(
            companionFields.copyWith(syncId: Value(syncId)));
        eventLocal[syncId] = id;
      } else {
        eventLocal[syncId] = existing.id;
        if (remoteUpdatedAt > existing.updatedAt) {
          await (db.update(db.calendarEvents)
                ..where((t) => t.id.equals(existing.id)))
              .write(companionFields);
        }
      }
      total++;
    }

    for (final doc in (await _col('event_reminders').get()).docs) {
      final d = doc.data();
      final syncId = d['syncId'] as String;
      final parentLocal = eventLocal[d['eventSyncId'] as String];
      if (parentLocal == null) continue; // parent missing — skip, don't crash
      final existing = await (db.select(db.eventReminders)
            ..where((t) => t.syncId.equals(syncId)))
          .getSingleOrNull();
      final remoteUpdatedAt = d['updatedAt'] as int;
      final customDateMs = d['customDate'] as int?;
      final companionFields = EventRemindersCompanion(
        updatedAt: Value(remoteUpdatedAt),
        eventId: Value(parentLocal),
        daysBefore: Value(d['daysBefore'] as int),
        customDate: Value(customDateMs != null
            ? DateTime.fromMillisecondsSinceEpoch(customDateMs)
            : null),
      );
      if (existing == null) {
        await db
            .into(db.eventReminders)
            .insert(companionFields.copyWith(syncId: Value(syncId)));
      } else if (remoteUpdatedAt > existing.updatedAt) {
        await (db.update(db.eventReminders)
              ..where((t) => t.id.equals(existing.id)))
            .write(companionFields);
      }
      total++;
    }

    final exerciseLocal = <String, int>{};
    for (final doc in (await _col('exercises').get()).docs) {
      final d = doc.data();
      final syncId = d['syncId'] as String;
      final categorySyncId = d['categorySyncId'] as String?;
      final bundleSyncId = d['archivedBundleSyncId'] as String?;
      final existing = await (db.select(db.exercises)
            ..where((t) => t.syncId.equals(syncId)))
          .getSingleOrNull();
      final remoteUpdatedAt = d['updatedAt'] as int;
      final lastPracticedMs = d['lastPracticed'] as int?;
      final companionFields = ExercisesCompanion(
        updatedAt: Value(remoteUpdatedAt),
        name: Value(d['name'] as String),
        categoryId: Value(
            categorySyncId != null ? categoryLocal[categorySyncId] : null),
        timesPracticed: Value(d['timesPracticed'] as int),
        totalMinutes: Value(d['totalMinutes'] as int),
        highestBpm: Value(d['highestBpm'] as int),
        lastBpm: Value(d['lastBpm'] as int),
        lastPracticed: Value(lastPracticedMs != null
            ? DateTime.fromMillisecondsSinceEpoch(lastPracticedMs)
            : null),
        reminderDays: Value(d['reminderDays'] as int),
        goalBpm: Value(d['goalBpm'] as int?),
        initialBpm: Value(d['initialBpm'] as int?),
        isArchived: Value(d['isArchived'] as bool),
        archivedIndividually: Value(d['archivedIndividually'] as bool),
        archivedCategoryBundleId: Value(
            bundleSyncId != null ? bundleLocal[bundleSyncId] : null),
      );
      if (existing == null) {
        final id = await db.into(db.exercises).insert(
            companionFields.copyWith(syncId: Value(syncId)));
        exerciseLocal[syncId] = id;
      } else {
        exerciseLocal[syncId] = existing.id;
        if (remoteUpdatedAt > existing.updatedAt) {
          await (db.update(db.exercises)
                ..where((t) => t.id.equals(existing.id)))
              .write(companionFields);
        }
      }
      total++;
    }

    for (final doc in (await _col('bpm_logs').get()).docs) {
      final d = doc.data();
      final syncId = d['syncId'] as String;
      final parentLocal = exerciseLocal[d['exerciseSyncId'] as String];
      if (parentLocal == null) continue;
      final existing = await (db.select(db.bpmLogs)
            ..where((t) => t.syncId.equals(syncId)))
          .getSingleOrNull();
      final remoteUpdatedAt = d['updatedAt'] as int;
      final companionFields = BpmLogsCompanion(
        updatedAt: Value(remoteUpdatedAt),
        exerciseId: Value(parentLocal),
        bpm: Value(d['bpm'] as int),
        loggedAt:
            Value(DateTime.fromMillisecondsSinceEpoch(d['loggedAt'] as int)),
      );
      if (existing == null) {
        await db
            .into(db.bpmLogs)
            .insert(companionFields.copyWith(syncId: Value(syncId)));
      } else if (remoteUpdatedAt > existing.updatedAt) {
        await (db.update(db.bpmLogs)..where((t) => t.id.equals(existing.id)))
            .write(companionFields);
      }
      total++;
    }

    for (final doc in (await _col('exercise_notes').get()).docs) {
      final d = doc.data();
      final syncId = d['syncId'] as String;
      final parentLocal = exerciseLocal[d['exerciseSyncId'] as String];
      if (parentLocal == null) continue;
      final existing = await (db.select(db.exerciseNotes)
            ..where((t) => t.syncId.equals(syncId)))
          .getSingleOrNull();
      final remoteUpdatedAt = d['updatedAt'] as int;
      final companionFields = ExerciseNotesCompanion(
        updatedAt: Value(remoteUpdatedAt),
        exerciseId: Value(parentLocal),
        noteText: Value(d['noteText'] as String),
        createdAt:
            Value(DateTime.fromMillisecondsSinceEpoch(d['createdAt'] as int)),
      );
      if (existing == null) {
        await db
            .into(db.exerciseNotes)
            .insert(companionFields.copyWith(syncId: Value(syncId)));
      } else if (remoteUpdatedAt > existing.updatedAt) {
        await (db.update(db.exerciseNotes)
              ..where((t) => t.id.equals(existing.id)))
            .write(companionFields);
      }
      total++;
    }

    for (final doc in (await _col('category_notes').get()).docs) {
      final d = doc.data();
      final syncId = d['syncId'] as String;
      final parentLocal = categoryLocal[d['categorySyncId'] as String];
      if (parentLocal == null) continue;
      final existing = await (db.select(db.categoryNotes)
            ..where((t) => t.syncId.equals(syncId)))
          .getSingleOrNull();
      final remoteUpdatedAt = d['updatedAt'] as int;
      final companionFields = CategoryNotesCompanion(
        updatedAt: Value(remoteUpdatedAt),
        categoryId: Value(parentLocal),
        noteText: Value(d['noteText'] as String),
        createdAt:
            Value(DateTime.fromMillisecondsSinceEpoch(d['createdAt'] as int)),
      );
      if (existing == null) {
        await db
            .into(db.categoryNotes)
            .insert(companionFields.copyWith(syncId: Value(syncId)));
      } else if (remoteUpdatedAt > existing.updatedAt) {
        await (db.update(db.categoryNotes)
              ..where((t) => t.id.equals(existing.id)))
            .write(companionFields);
      }
      total++;
    }

    for (final doc in (await _col('history_entries').get()).docs) {
      final d = doc.data();
      final syncId = d['syncId'] as String;
      final exerciseSyncId = d['exerciseSyncId'] as String?;
      final existing = await (db.select(db.historyEntries)
            ..where((t) => t.syncId.equals(syncId)))
          .getSingleOrNull();
      final remoteUpdatedAt = d['updatedAt'] as int;
      final companionFields = HistoryEntriesCompanion(
        updatedAt: Value(remoteUpdatedAt),
        exerciseId: Value(
            exerciseSyncId != null ? exerciseLocal[exerciseSyncId] : null),
        exerciseName: Value(d['exerciseName'] as String),
        date: Value(DateTime.fromMillisecondsSinceEpoch(d['date'] as int)),
        minutes: Value(d['minutes'] as int),
        bpm: Value(d['bpm'] as int),
        note: Value(d['note'] as String),
      );
      if (existing == null) {
        await db
            .into(db.historyEntries)
            .insert(companionFields.copyWith(syncId: Value(syncId)));
      } else if (remoteUpdatedAt > existing.updatedAt) {
        await (db.update(db.historyEntries)
              ..where((t) => t.id.equals(existing.id)))
            .write(companionFields);
      }
      total++;
    }

    final pieceLocal = <String, int>{};
    for (final doc in (await _col('metronome_pieces').get()).docs) {
      final d = doc.data();
      final syncId = d['syncId'] as String;
      final exerciseSyncId = d['exerciseSyncId'] as String?;
      final existing = await (db.select(db.metronomePieces)
            ..where((t) => t.syncId.equals(syncId)))
          .getSingleOrNull();
      final remoteUpdatedAt = d['updatedAt'] as int;
      final companionFields = MetronomePiecesCompanion(
        updatedAt: Value(remoteUpdatedAt),
        title: Value(d['title'] as String),
        createdAt:
            Value(DateTime.fromMillisecondsSinceEpoch(d['createdAt'] as int)),
        modifiedAt: Value(
            DateTime.fromMillisecondsSinceEpoch(d['modifiedAt'] as int)),
        isArchived: Value(d['isArchived'] as bool),
        exerciseId: Value(
            exerciseSyncId != null ? exerciseLocal[exerciseSyncId] : null),
      );
      if (existing == null) {
        final id = await db.into(db.metronomePieces).insert(
            companionFields.copyWith(syncId: Value(syncId)));
        pieceLocal[syncId] = id;
      } else {
        pieceLocal[syncId] = existing.id;
        if (remoteUpdatedAt > existing.updatedAt) {
          await (db.update(db.metronomePieces)
                ..where((t) => t.id.equals(existing.id)))
              .write(companionFields);
        }
      }
      total++;
    }

    for (final doc in (await _col('piece_sections').get()).docs) {
      final d = doc.data();
      final syncId = d['syncId'] as String;
      final parentLocal = pieceLocal[d['pieceSyncId'] as String];
      if (parentLocal == null) continue;
      final existing = await (db.select(db.pieceSections)
            ..where((t) => t.syncId.equals(syncId)))
          .getSingleOrNull();
      final remoteUpdatedAt = d['updatedAt'] as int;
      final companionFields = PieceSectionsCompanion(
        updatedAt: Value(remoteUpdatedAt),
        pieceId: Value(parentLocal),
        sortOrder: Value(d['sortOrder'] as int),
        startMeasure: Value(d['startMeasure'] as int),
        endMeasure: Value(d['endMeasure'] as int),
        bpm: Value(d['bpm'] as int),
        timeSignature: Value(d['timeSignature'] as String),
        subdivision: Value(d['subdivision'] as String),
        accentFirstBeat: Value(d['accentFirstBeat'] as bool),
      );
      if (existing == null) {
        await db
            .into(db.pieceSections)
            .insert(companionFields.copyWith(syncId: Value(syncId)));
      } else if (remoteUpdatedAt > existing.updatedAt) {
        await (db.update(db.pieceSections)
              ..where((t) => t.id.equals(existing.id)))
            .write(companionFields);
      }
      total++;
    }

    // Profile fields: only fill in what's blank locally — never clobber a
    // name/instrument the user already set on THIS device.
    final profileSnap = await _userDoc.get();
    final profile = profileSnap.data()?['profile'] as Map<String, dynamic>?;
    if (profile != null) {
      final prefs = await SharedPreferences.getInstance();
      final firstName = prefs.getString('first_name') ?? '';
      final instrument = prefs.getString('instrument') ?? '';
      if (firstName.isEmpty && (profile['firstName'] as String? ?? '').isNotEmpty) {
        await prefs.setString('first_name', profile['firstName'] as String);
      }
      final lastName = profile['lastName'] as String?;
      if ((prefs.getString('last_name') ?? '').isEmpty &&
          lastName != null &&
          lastName.isNotEmpty) {
        await prefs.setString('last_name', lastName);
      }
      if (instrument.isEmpty &&
          (profile['instrument'] as String? ?? '').isNotEmpty) {
        await prefs.setString('instrument', profile['instrument'] as String);
      }
    }

    await _writeTimestamp(keyLastRestoreAt, DateTime.now());
    return total;
  }
}

// ── Batched Firestore writer ──────────────────────────────────────────────────
//
// A single WriteBatch caps out at 500 operations; a practice history full of
// BPM logs blows past that easily. This accumulates writes and flushes in
// chunks transparently, so backup() doesn't need to think about the limit.
class _BatchWriter {
  final FirebaseFirestore _firestore;
  static const _maxOpsPerBatch = 400; // headroom under Firestore's 500 cap

  WriteBatch _batch;
  int _ops = 0;
  final List<Future<void>> _pending = [];

  _BatchWriter(this._firestore) : _batch = _firestore.batch();

  void _maybeFlush() {
    if (_ops < _maxOpsPerBatch) return;
    _pending.add(_batch.commit());
    _batch = _firestore.batch();
    _ops = 0;
  }

  void set(DocumentReference<Map<String, dynamic>> doc,
      Map<String, dynamic> data) {
    _batch.set(doc, data);
    _ops++;
    _maybeFlush();
  }

  void delete(DocumentReference<Map<String, dynamic>> doc) {
    _batch.delete(doc);
    _ops++;
    _maybeFlush();
  }

  Future<void> commit() async {
    if (_ops > 0) _pending.add(_batch.commit());
    await Future.wait(_pending);
  }
}
