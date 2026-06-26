import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/data/database/app_database.dart';
import 'database_provider.dart';

// ── Selected month (first day of that month) ──────────────────────────────────
final calendarMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

// ── Stream of all events ──────────────────────────────────────────────────────
final calendarEventsProvider =
    StreamProvider<List<CalendarEvent>>((ref) {
  return ref.watch(calendarRepositoryProvider).watchAll();
});

// ── Events visible in the current month (includes multi-day overflow) ─────────
final monthEventsProvider = Provider<List<CalendarEvent>>((ref) {
  final month = ref.watch(calendarMonthProvider);
  final allEvents = ref.watch(calendarEventsProvider).valueOrNull ?? [];

  final firstDay = DateTime.utc(month.year, month.month, 1);
  final lastDay = DateTime.utc(month.year, month.month + 1, 0, 23, 59, 59);

  return allEvents.where((e) {
    final start = e.startDate.toLocal();
    final end = e.endDate.toLocal();
    final startUtc = DateTime.utc(start.year, start.month, start.day);
    final endUtc = DateTime.utc(end.year, end.month, end.day, 23, 59, 59);
    return startUtc.isBefore(lastDay) && endUtc.isAfter(firstDay);
  }).toList();
});

// ── Upcoming events (next 30 days) ────────────────────────────────────────────
final upcomingEventsProvider = Provider<List<CalendarEvent>>((ref) {
  final allEvents = ref.watch(calendarEventsProvider).valueOrNull ?? [];
  final now = DateTime.now();
  final todayUtc = DateTime.utc(now.year, now.month, now.day);
  final cutoff = todayUtc.add(const Duration(days: 30));

  return allEvents.where((e) {
    final end = e.endDate.toLocal();
    final endUtc = DateTime.utc(end.year, end.month, end.day);
    return endUtc.isAfter(todayUtc.subtract(const Duration(days: 1))) &&
        e.startDate.isBefore(cutoff);
  }).toList()
    ..sort((a, b) => a.startDate.compareTo(b.startDate));
});

// ── Calendar reminder item ────────────────────────────────────────────────────
class CalendarReminderItem {
  final CalendarEvent event;
  final int daysUntilStart; // 0 = today, negative = already started

  const CalendarReminderItem({
    required this.event,
    required this.daysUntilStart,
  });

  String get dueLabel {
    if (daysUntilStart < 0) return 'In progress';
    if (daysUntilStart == 0) return 'Today';
    if (daysUntilStart == 1) return 'Tomorrow';
    return 'In $daysUntilStart days';
  }
}

// Internal stream — all reminder rows from DB
final _allEventRemindersProvider = StreamProvider<List<EventReminder>>((ref) {
  return ref.watch(calendarRepositoryProvider).watchAllReminders();
});

// Active calendar reminders: fire date has passed, event hasn't ended yet.
// One entry per event, sorted by soonest start date first.
final calendarRemindersProvider = Provider<List<CalendarReminderItem>>((ref) {
  final allEvents = ref.watch(calendarEventsProvider).valueOrNull ?? [];
  final allReminders = ref.watch(_allEventRemindersProvider).valueOrNull ?? [];

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final eventMap = {for (final e in allEvents) e.id: e};
  final Map<int, CalendarReminderItem> activeItems = {};

  for (final reminder in allReminders) {
    final event = eventMap[reminder.eventId];
    if (event == null) continue;

    final endLocal = event.endDate.toLocal();
    final startLocal = event.startDate.toLocal();
    final eventEnd = DateTime(endLocal.year, endLocal.month, endLocal.day);
    final eventStart = DateTime(startLocal.year, startLocal.month, startLocal.day);

    if (eventEnd.isBefore(today)) continue; // event already over

    DateTime fireDate;
    if (reminder.daysBefore == -1 && reminder.customDate != null) {
      final cd = reminder.customDate!.toLocal();
      fireDate = DateTime(cd.year, cd.month, cd.day);
    } else if (reminder.daysBefore >= 0) {
      fireDate = eventStart.subtract(Duration(days: reminder.daysBefore));
    } else {
      continue;
    }

    if (today.isBefore(fireDate)) continue; // not yet due

    final daysUntil = eventStart.difference(today).inDays;

    if (!activeItems.containsKey(event.id) ||
        daysUntil < activeItems[event.id]!.daysUntilStart) {
      activeItems[event.id] = CalendarReminderItem(
        event: event,
        daysUntilStart: daysUntil,
      );
    }
  }

  return activeItems.values.toList()
    ..sort((a, b) => a.daysUntilStart.compareTo(b.daysUntilStart));
});

// ── Event colors ──────────────────────────────────────────────────────────────
class EventColors {
  EventColors._();

  static const List<Color> palette = [
    Color(0xFF1976D2), // Blue
    Color(0xFF388E3C), // Green
    Color(0xFFD32F2F), // Red
    Color(0xFFF57C00), // Orange
    Color(0xFF7B1FA2), // Purple
    Color(0xFFF9A825), // Yellow
    Color(0xFFE91E63), // Pink
  ];

  static const List<String> names = [
    'Blue',
    'Green',
    'Red',
    'Orange',
    'Purple',
    'Yellow',
    'Pink',
  ];

  static Color? fromValue(int? value) =>
      value == null ? null : Color(value);

  static int toValue(Color color) => color.toARGB32();
}
