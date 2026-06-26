import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/data/database/app_database.dart';
import 'package:cadence/presentation/providers/history_provider.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final historyAsync = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Practice History')),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (history) {
          if (history.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.hourglass_empty,
                      size: 64,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary),
                  const SizedBox(height: 16),
                  Text('No sessions logged yet.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      )),
                ],
              ),
            );
          }

          // Group by date
          final grouped = _groupByDate(history);
          final dates = grouped.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: dates.length,
            itemBuilder: (_, i) {
              final date = dates[i];
              final entries = grouped[date]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 4, top: 8, bottom: 8),
                    child: Text(
                      _formatDateLabel(date),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ...entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _HistoryCard(entry: entry),
                      )),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Map<String, List<HistoryEntry>> _groupByDate(List<HistoryEntry> history) {
    final map = <String, List<HistoryEntry>>{};
    for (final entry in history) {
      // entry.date is UTC from Drift — convert to local before grouping so
      // sessions logged near midnight land on the correct calendar day.
      final key = DateFormat('yyyy-MM-dd').format(entry.date.toLocal());
      map.putIfAbsent(key, () => []).add(entry);
    }
    return map;
  }

  String _formatDateLabel(String isoDate) {
    final date = DateTime.parse(isoDate);
    final now = DateTime.now();
    // Use UTC midnights for the Today/Yesterday comparison so DST transitions
    // (where local midnight-to-midnight != 86400 s) don't break the label.
    final todayUTC = DateTime.utc(now.year, now.month, now.day);
    final yesterdayUTC = todayUTC.subtract(const Duration(days: 1));
    final dUTC = DateTime.utc(date.year, date.month, date.day);

    if (dUTC == todayUTC) return 'Today';
    if (dUTC == yesterdayUTC) return 'Yesterday';
    return DateFormat('MMMM d, yyyy').format(date);
  }
}

class _HistoryCard extends StatelessWidget {
  final HistoryEntry entry;
  const _HistoryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    entry.exerciseName,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  DateFormat('h:mm a').format(entry.date.toLocal()),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _Chip(icon: Icons.timer_outlined, label: '${entry.minutes} min'),
                const SizedBox(width: 8),
                _Chip(icon: Icons.speed_outlined, label: '${entry.bpm} BPM'),
              ],
            ),
            if (entry.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.edit_note_outlined,
                      size: 14,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      entry.note,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}
