import 'package:drift/drift.dart';
import 'package:cadence/data/database/app_database.dart';

class CalendarRepository {
  final AppDatabase _db;
  const CalendarRepository(this._db);

  // ── Events ────────────────────────────────────────────────────────────────

  Stream<List<CalendarEvent>> watchAll() {
    return (_db.select(_db.calendarEvents)
          ..orderBy([(e) => OrderingTerm.asc(e.startDate)]))
        .watch();
  }

  // Events whose range overlaps [rangeStart, rangeEnd] (inclusive)
  Stream<List<CalendarEvent>> watchEventsInRange(
      DateTime rangeStart, DateTime rangeEnd) {
    return (_db.select(_db.calendarEvents)
          ..where((e) =>
              e.startDate.isSmallerOrEqualValue(rangeEnd) &
              e.endDate.isBiggerOrEqualValue(rangeStart))
          ..orderBy([(e) => OrderingTerm.asc(e.startDate)]))
        .watch();
  }

  Future<List<CalendarEvent>> getEventsInRange(
      DateTime rangeStart, DateTime rangeEnd) {
    return (_db.select(_db.calendarEvents)
          ..where((e) =>
              e.startDate.isSmallerOrEqualValue(rangeEnd) &
              e.endDate.isBiggerOrEqualValue(rangeStart))
          ..orderBy([(e) => OrderingTerm.asc(e.startDate)]))
        .get();
  }

  Future<CalendarEvent?> getById(int id) {
    return (_db.select(_db.calendarEvents)..where((e) => e.id.equals(id)))
        .getSingleOrNull();
  }

  Future<int> createEvent({
    required String title,
    String notes = '',
    required DateTime startDate,
    required DateTime endDate,
    int? colorValue,
  }) {
    return _db.into(_db.calendarEvents).insert(
          CalendarEventsCompanion.insert(
            title: title,
            notes: Value(notes),
            startDate: startDate,
            endDate: endDate,
            colorValue: Value(colorValue),
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<void> updateEvent(int id, CalendarEventsCompanion companion) {
    return (_db.update(_db.calendarEvents)..where((e) => e.id.equals(id)))
        .write(companion);
  }

  Future<void> deleteEvent(int id) async {
    await deleteRemindersForEvent(id);
    await (_db.delete(_db.calendarEvents)..where((e) => e.id.equals(id))).go();
  }

  Future<void> deleteAll() async {
    await _db.delete(_db.eventReminders).go();
    await _db.delete(_db.calendarEvents).go();
  }

  // ── Reminders ─────────────────────────────────────────────────────────────

  Stream<List<EventReminder>> watchAllReminders() {
    return (_db.select(_db.eventReminders)).watch();
  }

  Future<List<EventReminder>> getRemindersForEvent(int eventId) {
    return (_db.select(_db.eventReminders)
          ..where((r) => r.eventId.equals(eventId))
          ..orderBy([(r) => OrderingTerm.desc(r.daysBefore)]))
        .get();
  }

  Future<int> addReminder(int eventId, int daysBefore,
      {DateTime? customDate}) {
    return _db.into(_db.eventReminders).insert(
          EventRemindersCompanion.insert(
            eventId: eventId,
            daysBefore: daysBefore,
            customDate: Value(customDate),
          ),
        );
  }

  Future<void> deleteReminder(int reminderId) {
    return (_db.delete(_db.eventReminders)
          ..where((r) => r.id.equals(reminderId)))
        .go();
  }

  Future<void> deleteRemindersForEvent(int eventId) {
    return (_db.delete(_db.eventReminders)
          ..where((r) => r.eventId.equals(eventId)))
        .go();
  }
}
