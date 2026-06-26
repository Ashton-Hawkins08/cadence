import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/data/database/app_database.dart';
import 'package:cadence/domain/services/date_service.dart';
import 'categories_provider.dart';
import 'exercises_provider.dart';

// ── Practice reminder item ─────────────────────────────────────────────────────
// One item per category (or per uncategorized exercise).
// Only shown when the category/exercise has been practiced at least once AND
// no exercise in that group has been practiced within its own reminderDays.

class PracticeReminderItem {
  final String displayName;   // category name OR exercise name (uncategorized)
  final int? categoryId;      // null = uncategorized individual exercise
  final int daysSince;        // days since most recent practice in this group
  final int threshold;        // min reminderDays across the group
  final int daysOverdue;      // daysSince - threshold

  const PracticeReminderItem({
    required this.displayName,
    required this.categoryId,
    required this.daysSince,
    required this.threshold,
    required this.daysOverdue,
  });
}

final practiceRemindersProvider = Provider<List<PracticeReminderItem>>((ref) {
  final exercises = ref.watch(exercisesProvider).valueOrNull ?? [];
  final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
  final categoryMap = {for (final c in categories) c.id: c.name};

  final result = <PracticeReminderItem>[];

  // ── Categorized exercises — group by categoryId ───────────────────────────
  final grouped = <int, List<Exercise>>{};
  final uncategorized = <Exercise>[];

  for (final ex in exercises) {
    if (ex.categoryId != null) {
      grouped.putIfAbsent(ex.categoryId!, () => []).add(ex);
    } else {
      uncategorized.add(ex);
    }
  }

  for (final entry in grouped.entries) {
    final catId = entry.key;
    final group = entry.value;
    final categoryName = categoryMap[catId] ?? 'Unknown Category';

    // Only consider exercises that have been practiced at least once
    final practiced = group.where((e) => e.lastPracticed != null).toList();
    if (practiced.isEmpty) continue; // skip — never started this category

    // If ANY exercise was practiced within its own reminderDays → category ok
    final anySatisfied = practiced.any((e) {
      final days = DateService.daysSince(e.lastPracticed!);
      return days < e.reminderDays;
    });
    if (anySatisfied) continue;

    // All practiced exercises are overdue — show a category reminder
    final daysSince = practiced
        .map((e) => DateService.daysSince(e.lastPracticed!))
        .reduce((a, b) => a < b ? a : b); // most recent in the group
    final threshold = practiced
        .map((e) => e.reminderDays)
        .reduce((a, b) => a < b ? a : b); // strictest threshold

    result.add(PracticeReminderItem(
      displayName: categoryName,
      categoryId: catId,
      daysSince: daysSince,
      threshold: threshold,
      daysOverdue: daysSince - threshold,
    ));
  }

  // ── Uncategorized — individual (only if practiced at least once) ──────────
  for (final ex in uncategorized) {
    if (ex.lastPracticed == null) continue; // never practiced — skip
    final days = DateService.daysSince(ex.lastPracticed!);
    if (days < ex.reminderDays) continue; // practiced recently enough
    result.add(PracticeReminderItem(
      displayName: ex.name,
      categoryId: null,
      daysSince: days,
      threshold: ex.reminderDays,
      daysOverdue: days - ex.reminderDays,
    ));
  }

  // Most overdue first
  result.sort((a, b) => b.daysOverdue.compareTo(a.daysOverdue));
  return result;
});

// Legacy count provider — used for combined badge count
final reminderCountProvider = Provider<int>((ref) {
  return ref.watch(practiceRemindersProvider).length;
});

// Keep old name as alias so any existing callers don't break
final remindersProvider = practiceRemindersProvider;
