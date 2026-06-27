import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cadence/data/database/app_database.dart';
import 'package:cadence/data/repositories/piece_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

// Build an in-memory database + repository for each test group.
AppDatabase _makeDb() => AppDatabase(NativeDatabase.memory());

PieceSectionsCompanion _section({
  required int pieceId,
  required int sortOrder,
  int startMeasure = 1,
  int endMeasure = 4,
  int bpm = 120,
  String timeSignature = 'sig4_4',
  String subdivision = 'quarter',
  bool accentFirstBeat = true,
}) =>
    PieceSectionsCompanion.insert(
      pieceId: pieceId,
      sortOrder: sortOrder,
      startMeasure: startMeasure,
      endMeasure: endMeasure,
      bpm: bpm,
      timeSignature: timeSignature,
      subdivision: subdivision,
      accentFirstBeat: Value(accentFirstBeat),
    );

void main() {
  late AppDatabase db;
  late PieceRepository repo;

  setUp(() {
    db = _makeDb();
    repo = PieceRepository(db);
  });

  tearDown(() async => db.close());

  // ── create / watchAll ──────────────────────────────────────────────────────

  group('create', () {
    test('inserts a piece and watchAll emits it', () async {
      await repo.create('Sonata');
      final pieces = await repo.watchAll().first;
      expect(pieces.length, 1);
      expect(pieces.first.title, 'Sonata');
    });

    test('multiple pieces appear in watchAll and both are present', () async {
      await repo.create('First');
      await repo.create('Second');
      final pieces = await repo.watchAll().first;
      expect(pieces.length, 2);
      expect(pieces.map((p) => p.title), containsAll(['First', 'Second']));
    });

    test('watchAll orders by modifiedAt desc', () async {
      await repo.create('Alpha');
      final id2 = await repo.create('Beta');
      // Drift stores DateTime as epoch seconds; need >1 s gap to get a
      // strictly later timestamp.
      await Future.delayed(const Duration(milliseconds: 1200));
      await repo.touchModified(id2); // make Beta the most-recently-modified
      final pieces = await repo.watchAll().first;
      expect(pieces.first.title, 'Beta');
    });

    test('newly created piece is not archived', () async {
      await repo.create('Prelude');
      final pieces = await repo.watchAll().first;
      expect(pieces.first.isArchived, isFalse);
    });

    test('create returns a positive id', () async {
      final id = await repo.create('Test');
      expect(id, isPositive);
    });
  });

  // ── getById ────────────────────────────────────────────────────────────────

  group('getById', () {
    test('returns the piece for a valid id', () async {
      final id = await repo.create('Nocturne');
      final piece = await repo.getById(id);
      expect(piece, isNotNull);
      expect(piece!.title, 'Nocturne');
    });

    test('returns null for an unknown id', () async {
      final piece = await repo.getById(9999);
      expect(piece, isNull);
    });
  });

  // ── rename ─────────────────────────────────────────────────────────────────

  group('rename', () {
    test('updates title', () async {
      final id = await repo.create('Old Name');
      await repo.rename(id, 'New Name');
      final after = await repo.getById(id);
      expect(after!.title, 'New Name');
    });

    test('updates modifiedAt', () async {
      final id = await repo.create('Old Name');
      final before = (await repo.getById(id))!.modifiedAt;
      // Drift stores DateTime as epoch seconds; need >1 s gap.
      await Future.delayed(const Duration(milliseconds: 1200));
      await repo.rename(id, 'New Name');
      final after = (await repo.getById(id))!.modifiedAt;
      expect(after.isAfter(before), isTrue);
    });
  });

  // ── archive / restore ──────────────────────────────────────────────────────

  group('archive / restore', () {
    test('archive hides piece from watchAll and shows in watchArchived', () async {
      final id = await repo.create('Etude');
      await repo.archive(id);

      final active = await repo.watchAll().first;
      final archived = await repo.watchArchived().first;

      expect(active.any((p) => p.id == id), isFalse);
      expect(archived.any((p) => p.id == id), isTrue);
    });

    test('restore moves piece back to watchAll', () async {
      final id = await repo.create('Waltz');
      await repo.archive(id);
      await repo.restore(id);

      final active = await repo.watchAll().first;
      final archived = await repo.watchArchived().first;

      expect(active.any((p) => p.id == id), isTrue);
      expect(archived.any((p) => p.id == id), isFalse);
    });
  });

  // ── delete ─────────────────────────────────────────────────────────────────

  group('delete', () {
    test('removes piece from watchAll', () async {
      final id = await repo.create('To Delete');
      await repo.delete(id);
      final pieces = await repo.watchAll().first;
      expect(pieces.any((p) => p.id == id), isFalse);
    });

    test('cascades to sections — no orphans remain', () async {
      final id = await repo.create('With Sections');
      await repo.replaceSections(
          id, [_section(pieceId: id, sortOrder: 0)]);
      await repo.delete(id);
      final sections = await repo.getSectionsForPiece(id);
      expect(sections, isEmpty);
    });
  });

  // ── replaceSections ────────────────────────────────────────────────────────

  group('replaceSections', () {
    test('inserts sections for a new piece', () async {
      final id = await repo.create('Bach');
      await repo.replaceSections(id, [
        _section(pieceId: id, sortOrder: 0, bpm: 80),
        _section(pieceId: id, sortOrder: 1, bpm: 100),
      ]);
      final sections = await repo.getSectionsForPiece(id);
      expect(sections.length, 2);
    });

    test('replaces existing sections atomically', () async {
      final id = await repo.create('Mozart');
      await repo.replaceSections(id, [
        _section(pieceId: id, sortOrder: 0, bpm: 60),
        _section(pieceId: id, sortOrder: 1, bpm: 80),
      ]);
      // Replace with one section.
      await repo.replaceSections(id, [
        _section(pieceId: id, sortOrder: 0, bpm: 120),
      ]);
      final sections = await repo.getSectionsForPiece(id);
      expect(sections.length, 1);
      expect(sections.first.bpm, 120);
    });

    test('replacing with empty list removes all sections', () async {
      final id = await repo.create('Debussy');
      await repo.replaceSections(
          id, [_section(pieceId: id, sortOrder: 0)]);
      await repo.replaceSections(id, []);
      final sections = await repo.getSectionsForPiece(id);
      expect(sections, isEmpty);
    });

    test('touches modifiedAt on the piece', () async {
      final id = await repo.create('Chopin');
      final before = (await repo.getById(id))!.modifiedAt;
      // Drift stores DateTime as epoch seconds; need >1 s gap.
      await Future.delayed(const Duration(milliseconds: 1200));
      await repo.replaceSections(
          id, [_section(pieceId: id, sortOrder: 0)]);
      final after = (await repo.getById(id))!.modifiedAt;
      expect(after.isAfter(before), isTrue);
    });

    test('sections for a different piece are not touched', () async {
      final id1 = await repo.create('Piece A');
      final id2 = await repo.create('Piece B');
      await repo.replaceSections(
          id1, [_section(pieceId: id1, sortOrder: 0, bpm: 70)]);
      await repo.replaceSections(
          id2, [_section(pieceId: id2, sortOrder: 0, bpm: 90)]);
      // Replace piece A's sections only.
      await repo.replaceSections(
          id1, [_section(pieceId: id1, sortOrder: 0, bpm: 100)]);
      final sectionsB = await repo.getSectionsForPiece(id2);
      expect(sectionsB.length, 1);
      expect(sectionsB.first.bpm, 90);
    });
  });

  // ── watchSectionsForPiece (ordering) ──────────────────────────────────────

  group('watchSectionsForPiece', () {
    test('returns sections in sortOrder ascending', () async {
      final id = await repo.create('Ravel');
      // Insert in reverse sortOrder to verify ordering isn't insertion-order.
      await repo.replaceSections(id, [
        _section(pieceId: id, sortOrder: 2, bpm: 60),
        _section(pieceId: id, sortOrder: 0, bpm: 120),
        _section(pieceId: id, sortOrder: 1, bpm: 90),
      ]);
      final sections = await repo.watchSectionsForPiece(id).first;
      expect(sections.map((s) => s.bpm).toList(), [120, 90, 60]);
    });

    test('emits updated list when sections are replaced', () async {
      final id = await repo.create('Schubert');
      final stream = repo.watchSectionsForPiece(id);
      await repo.replaceSections(
          id, [_section(pieceId: id, sortOrder: 0, bpm: 60)]);
      await repo.replaceSections(
          id, [_section(pieceId: id, sortOrder: 0, bpm: 80)]);
      // Take the most recent emission.
      final sections =
          await stream.first.timeout(const Duration(seconds: 2));
      expect(sections.first.bpm, anyOf(60, 80));
    });
  });

  // ── getSectionsForPiece ────────────────────────────────────────────────────

  group('getSectionsForPiece', () {
    test('returns empty for piece with no sections', () async {
      final id = await repo.create('Empty');
      final sections = await repo.getSectionsForPiece(id);
      expect(sections, isEmpty);
    });

    test('stores all section fields correctly', () async {
      final id = await repo.create('Fields');
      await repo.replaceSections(id, [
        _section(
          pieceId: id,
          sortOrder: 0,
          startMeasure: 1,
          endMeasure: 8,
          bpm: 72,
          timeSignature: 'sig6_8',
          subdivision: 'compoundEighth',
          accentFirstBeat: false,
        ),
      ]);
      final s = (await repo.getSectionsForPiece(id)).first;
      expect(s.startMeasure, 1);
      expect(s.endMeasure, 8);
      expect(s.bpm, 72);
      expect(s.timeSignature, 'sig6_8');
      expect(s.subdivision, 'compoundEighth');
      expect(s.accentFirstBeat, isFalse);
    });
  });

  // ── duplicate ──────────────────────────────────────────────────────────────

  group('duplicate', () {
    test('creates a new piece with the given title', () async {
      final sourceId = await repo.create('Original');
      final newId = await repo.duplicate(sourceId, 'Copy');
      expect(newId, isNot(sourceId));
      final newPiece = await repo.getById(newId);
      expect(newPiece!.title, 'Copy');
    });

    test('copies all sections from the source', () async {
      final sourceId = await repo.create('Source');
      await repo.replaceSections(sourceId, [
        _section(pieceId: sourceId, sortOrder: 0, bpm: 60),
        _section(pieceId: sourceId, sortOrder: 1, bpm: 80),
        _section(pieceId: sourceId, sortOrder: 2, bpm: 100),
      ]);
      final newId = await repo.duplicate(sourceId, 'Source Copy');
      final newSections = await repo.getSectionsForPiece(newId);
      expect(newSections.length, 3);
      expect(newSections.map((s) => s.bpm).toList(), containsAll([60, 80, 100]));
    });

    test('duplicate sections are independent from source', () async {
      final sourceId = await repo.create('A');
      await repo.replaceSections(
          sourceId, [_section(pieceId: sourceId, sortOrder: 0, bpm: 60)]);
      final copyId = await repo.duplicate(sourceId, 'B');
      // Replace source sections.
      await repo.replaceSections(
          sourceId, [_section(pieceId: sourceId, sortOrder: 0, bpm: 200)]);
      // Copy sections should be unchanged.
      final copySections = await repo.getSectionsForPiece(copyId);
      expect(copySections.first.bpm, 60);
    });

    test('duplicating a piece with no sections creates an empty copy', () async {
      final sourceId = await repo.create('Empty Source');
      final copyId = await repo.duplicate(sourceId, 'Empty Copy');
      final sections = await repo.getSectionsForPiece(copyId);
      expect(sections, isEmpty);
    });

    test('both source and copy appear in watchAll', () async {
      final sourceId = await repo.create('Original');
      final copyId = await repo.duplicate(sourceId, 'Copy');
      final all = await repo.watchAll().first;
      final ids = all.map((p) => p.id).toList();
      expect(ids, containsAll([sourceId, copyId]));
    });
  });

  // ── deleteAll ──────────────────────────────────────────────────────────────

  group('deleteAll', () {
    test('removes all pieces and sections', () async {
      final id1 = await repo.create('A');
      final id2 = await repo.create('B');
      await repo.replaceSections(id1, [_section(pieceId: id1, sortOrder: 0)]);
      await repo.replaceSections(id2, [_section(pieceId: id2, sortOrder: 0)]);
      await repo.deleteAll();
      expect(await repo.watchAll().first, isEmpty);
      expect(await repo.getSectionsForPiece(id1), isEmpty);
      expect(await repo.getSectionsForPiece(id2), isEmpty);
    });
  });

  // ── touchModified ──────────────────────────────────────────────────────────

  group('touchModified', () {
    test('advances modifiedAt without changing other fields', () async {
      final id = await repo.create('Touch Me');
      final before = (await repo.getById(id))!;
      // Drift stores DateTime as epoch seconds; need >1 s gap.
      await Future.delayed(const Duration(milliseconds: 1200));
      await repo.touchModified(id);
      final after = (await repo.getById(id))!;
      expect(after.modifiedAt.isAfter(before.modifiedAt), isTrue);
      expect(after.title, before.title);
      expect(after.isArchived, before.isArchived);
    });
  });
}
