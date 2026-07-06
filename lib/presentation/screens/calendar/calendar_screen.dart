import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/data/database/app_database.dart';
import 'package:cadence/presentation/providers/calendar_provider.dart';
import 'package:cadence/presentation/providers/database_provider.dart';
import 'package:intl/intl.dart';

import 'create_event_screen.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMonth = ref.watch(calendarMonthProvider);
    final eventsAsync = ref.watch(calendarEventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today_outlined),
            tooltip: 'Go to today',
            onPressed: () {
              final now = DateTime.now();
              ref.read(calendarMonthProvider.notifier).state =
                  DateTime(now.year, now.month, 1);
            },
          ),
        ],
      ),
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (allEvents) {
          return Column(
            children: [
              _MonthHeader(currentMonth: currentMonth),
              _DayLabelsRow(),
              Expanded(
                child: _CalendarGrid(
                  currentMonth: currentMonth,
                  allEvents: allEvents,
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCreate(context, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _openCreate(BuildContext context, DateTime? date) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateEventScreen(initialDate: date),
      ),
    );
  }
}

// ─── Month header with prev/next and year picker ──────────────────────────────

class _MonthHeader extends ConsumerWidget {
  final DateTime currentMonth;
  const _MonthHeader({required this.currentMonth});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeMonth(ref, -1),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _pickYear(context, ref),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('MMMM').format(currentMonth),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        currentMonth.year.toString(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(Icons.arrow_drop_down,
                          size: 16, color: theme.colorScheme.primary),
                    ],
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _changeMonth(ref, 1),
          ),
        ],
      ),
    );
  }

  void _changeMonth(WidgetRef ref, int delta) {
    final m = ref.read(calendarMonthProvider);
    ref.read(calendarMonthProvider.notifier).state =
        DateTime(m.year, m.month + delta, 1);
  }

  Future<void> _pickYear(BuildContext context, WidgetRef ref) async {
    final current = ref.read(calendarMonthProvider);
    int? picked;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: Duration.zero,
      pageBuilder: (ctx, _, __) => _YearPickerDialog(
        selectedYear: current.year,
        onPick: (y) {
          picked = y;
          Navigator.pop(ctx);
        },
      ),
    );

    if (picked != null) {
      ref.read(calendarMonthProvider.notifier).state =
          DateTime(picked!, current.month, 1);
    }
  }
}

// ─── Day-of-week labels row ───────────────────────────────────────────────────

class _DayLabelsRow extends StatelessWidget {
  const _DayLabelsRow();

  static const _labels = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: _labels
            .map((l) => Expanded(
                  child: Center(
                    child: Text(
                      l,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ─── Calendar grid ────────────────────────────────────────────────────────────

class _CalendarGrid extends ConsumerWidget {
  final DateTime currentMonth;
  final List<CalendarEvent> allEvents;

  const _CalendarGrid({
    required this.currentMonth,
    required this.allEvents,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = _buildDaysGrid(currentMonth.year, currentMonth.month);
    final today = DateTime.now();
    final todayNorm =
        DateTime(today.year, today.month, today.day);

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.85,
      ),
      itemCount: days.length,
      itemBuilder: (context, i) {
        final day = days[i];
        if (day == null) return const SizedBox.shrink();

        final date = DateTime(currentMonth.year, currentMonth.month, day);
        final isToday = date == todayNorm;
        final events = _eventsForDay(date);

        return _DayCell(
          day: day,
          isToday: isToday,
          events: events,
          onTap: () => _handleDayTap(context, ref, date, events),
        );
      },
    );
  }

  List<int?> _buildDaysGrid(int year, int month) {
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // weekday: Mon=1…Sun=7 → convert to Sun=0 offset
    final offset = firstDay.weekday % 7;

    final days = <int?>[];
    for (int i = 0; i < offset; i++) days.add(null);
    for (int d = 1; d <= daysInMonth; d++) days.add(d);
    while (days.length % 7 != 0) days.add(null);
    return days;
  }

  List<CalendarEvent> _eventsForDay(DateTime date) {
    final dayUtc = DateTime.utc(date.year, date.month, date.day);
    final dayEnd =
        DateTime.utc(date.year, date.month, date.day, 23, 59, 59);

    return allEvents.where((e) {
      return e.startDate.isBefore(dayEnd) &&
          e.endDate.isAfter(
              dayUtc.subtract(const Duration(seconds: 1)));
    }).toList();
  }

  void _handleDayTap(BuildContext context, WidgetRef ref, DateTime date,
      List<CalendarEvent> events) {
    if (events.isEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateEventScreen(initialDate: date),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => _DayEventsSheet(
          date: date,
          events: events,
        ),
      );
    }
  }
}

// ─── Day cell ─────────────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  final int day;
  final bool isToday;
  final List<CalendarEvent> events;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.isToday,
    required this.events,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isToday ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight:
                    isToday ? FontWeight.w700 : FontWeight.normal,
                color: isToday
                    ? Colors.white
                    : isDark
                        ? AppColors.darkText
                        : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 3),
            _EventDots(events: events, isToday: isToday),
          ],
        ),
      ),
    );
  }
}

class _EventDots extends StatelessWidget {
  final List<CalendarEvent> events;
  final bool isToday;

  const _EventDots({required this.events, required this.isToday});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox(height: 6);
    final theme = Theme.of(context);
    final visible = events.take(3).toList();

    return SizedBox(
      height: 6,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: visible.map((e) {
          final color = EventColors.fromValue(e.colorValue) ??
              (isToday ? Colors.white70 : theme.colorScheme.primary);
          return Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Day events bottom sheet ──────────────────────────────────────────────────

class _DayEventsSheet extends StatelessWidget {
  final DateTime date;
  final List<CalendarEvent> events;

  const _DayEventsSheet({required this.date, required this.events});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMMM d, yyyy').format(date),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CreateEventScreen(initialDate: date),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add event'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              itemCount: events.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _EventListTile(
                event: events[i],
                onTap: () {
                  Navigator.pop(context);
                  _openDetail(context, events[i]);
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context, CalendarEvent event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _EventDetailScreen(event: event),
      ),
    );
  }
}

class _EventListTile extends StatelessWidget {
  final CalendarEvent event;
  final VoidCallback onTap;

  const _EventListTile({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        EventColors.fromValue(event.colorValue) ?? theme.colorScheme.primary;

    // Dates are stored as UTC midnight; extract the UTC year/month/day directly
    // rather than calling toLocal(), which shifts midnight back one day in
    // negative-offset timezones (e.g. Jun 21 00:00 UTC → Jun 20 in UTC-5).
    final start = DateTime(event.startDate.year, event.startDate.month, event.startDate.day);
    final end   = DateTime(event.endDate.year,   event.endDate.month,   event.endDate.day);
    final isSingleDay = start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        title: Text(event.title,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: isSingleDay
            ? null
            : Text(
                '${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d').format(end)}',
                style: theme.textTheme.bodySmall,
              ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: onTap,
      ),
    );
  }
}

// ─── Event detail screen ──────────────────────────────────────────────────────

class _EventDetailScreen extends ConsumerStatefulWidget {
  final CalendarEvent event;
  const _EventDetailScreen({required this.event});

  @override
  ConsumerState<_EventDetailScreen> createState() =>
      _EventDetailScreenState();
}

class _EventDetailScreenState
    extends ConsumerState<_EventDetailScreen> {
  List<EventReminder> _reminders = [];

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    final r = await ref
        .read(calendarRepositoryProvider)
        .getRemindersForEvent(widget.event.id);
    if (mounted) setState(() => _reminders = r);
  }

  Future<void> _delete() async {
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: Duration.zero,
      pageBuilder: (ctx, _, __) => AlertDialog(
        title: const Text('Delete Event?'),
        content: Text(
            'Delete "${widget.event.title}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await ref
        .read(calendarRepositoryProvider)
        .deleteEvent(widget.event.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ev = widget.event;
    final color =
        EventColors.fromValue(ev.colorValue) ?? theme.colorScheme.primary;

    // Same UTC-midnight extraction as _EventListTile — avoid toLocal() rollback.
    final start = DateTime(ev.startDate.year, ev.startDate.month, ev.startDate.day);
    final end   = DateTime(ev.endDate.year,   ev.endDate.month,   ev.endDate.day);
    final isSingleDay = start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;

    final dateLabel = isSingleDay
        ? DateFormat('MMMM d, yyyy').format(start)
        : '${DateFormat('MMM d, yyyy').format(start)} – ${DateFormat('MMM d, yyyy').format(end)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () async {
              final updated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateEventScreen(editingEvent: ev),
                ),
              );
              if (updated == true && mounted) {
                Navigator.pop(context);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            tooltip: 'Delete',
            onPressed: _delete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Color bar + title
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 5,
                height: 48,
                margin: const EdgeInsets.only(right: 12, top: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Expanded(
                child: Text(
                  ev.title,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _DetailRow(
            icon: Icons.calendar_today_outlined,
            text: dateLabel,
          ),

          if (ev.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.notes_outlined,
              text: ev.notes,
            ),
          ],

          if (_reminders.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Reminders',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ..._reminders.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(Icons.notifications_outlined,
                          size: 16,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary),
                      const SizedBox(width: 8),
                      Text(_reminderLabel(r),
                          style: theme.textTheme.bodyMedium),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  String _reminderLabel(EventReminder r) {
    if (r.daysBefore == -1 && r.customDate != null) {
      final cd = r.customDate!;
      return 'Custom: ${DateFormat('MMM d, yyyy').format(DateTime(cd.year, cd.month, cd.day))}';
    }
    return switch (r.daysBefore) {
      0 => 'Same day',
      1 => '1 day before',
      2 => '2 days before',
      3 => '3 days before',
      7 => '1 week before',
      _ => '${r.daysBefore} days before',
    };
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _DetailRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon,
            size: 18,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

// ─── Year picker dialog ───────────────────────────────────────────────────────

class _YearPickerDialog extends StatefulWidget {
  final int selectedYear;
  final void Function(int) onPick;

  const _YearPickerDialog(
      {required this.selectedYear, required this.onPick});

  @override
  State<_YearPickerDialog> createState() => _YearPickerDialogState();
}

class _YearPickerDialogState extends State<_YearPickerDialog> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    // Each row is 4 years; each cell is ~56px tall — jump to selected year
    final rowIndex = (widget.selectedYear - 2000) ~/ 4;
    _controller = ScrollController(
      initialScrollOffset: (rowIndex * 56.0).clamp(0.0, double.infinity),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final years = List.generate(51, (i) => 2000 + i);

    return AlertDialog(
      title: const Text('Select Year'),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      content: SizedBox(
        width: 260,
        height: 280,
        child: GridView.builder(
          controller: _controller,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 1.4,
          ),
          itemCount: years.length,
          itemBuilder: (_, i) {
            final y = years[i];
            final isSelected = y == widget.selectedYear;
            return GestureDetector(
              onTap: () => widget.onPick(y),
              child: Container(
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$y',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isSelected ? Colors.white : null,
                    fontWeight: isSelected ? FontWeight.w700 : null,
                  ),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
