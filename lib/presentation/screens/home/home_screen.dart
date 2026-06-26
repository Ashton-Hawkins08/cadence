import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/presentation/providers/settings_provider.dart';
import 'package:cadence/presentation/providers/streak_provider.dart';
import 'package:cadence/presentation/providers/stats_provider.dart';
import 'package:cadence/presentation/providers/reminders_provider.dart';
import 'package:cadence/presentation/providers/calendar_provider.dart';
import 'package:cadence/presentation/providers/history_provider.dart';
import 'package:cadence/presentation/screens/settings/settings_screen.dart';
import 'package:cadence/presentation/screens/metronome/metronome_shell.dart';
import 'package:intl/intl.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider).valueOrNull;
    final streak = ref.watch(streakProvider).valueOrNull;
    final readiness = ref.watch(readinessProvider);
    final readinessLabel = ref.watch(readinessLabelProvider);
    final practiceReminders = ref.watch(practiceRemindersProvider);
    final calendarReminders = ref.watch(calendarRemindersProvider);
    final history = ref.watch(historyProvider).valueOrNull ?? [];
    final avgBpm = ref.watch(overallAvgBpmProvider).valueOrNull;
    final hasReminders =
        practiceReminders.isNotEmpty || calendarReminders.isNotEmpty;

    final firstName = settings?.firstName ?? '';
    final instrument = settings?.instrument ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                firstName.isNotEmpty
                    ? 'Welcome back, $firstName'
                    : 'Welcome back',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (instrument.isNotEmpty)
              Text(
                instrument,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.av_timer),
            tooltip: 'Metronome',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MetronomeShell()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => const SettingsScreen(),
                transitionsBuilder: (_, animation, __, child) =>
                    SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1.0, 0.0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                      parent: animation, curve: Curves.easeOutCubic)),
                  child: child,
                ),
                transitionDuration: const Duration(milliseconds: 280),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Dashboard Card ──────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Readiness Score',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '${readiness.round()}%',
                                style:
                                    theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                readinessLabel,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      _ReadinessMeter(score: readiness),
                    ],
                  ),

                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: readiness / 100,
                      backgroundColor: isDark
                          ? AppColors.darkDivider
                          : AppColors.lightDivider,
                      color: AppColors.indigoNavy,
                      minHeight: 6,
                    ),
                  ),

                  const Divider(height: 32),

                  Row(
                    children: [
                      Expanded(
                        child: _StatItem(
                          label: 'Average BPM',
                          value: avgBpm != null
                              ? avgBpm.toStringAsFixed(0)
                              : '—',
                        ),
                      ),
                      Expanded(
                        child: _StreakItem(streak: streak, isDark: isDark),
                      ),
                      Expanded(
                        child: _StatItem(
                          label: 'Longest',
                          value:
                              streak != null ? '${streak.longest}d' : '0d',
                        ),
                      ),
                    ],
                  ),

                  if (streak != null && streak.hasDebt) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color:
                            AppColors.streakDebt.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_outlined,
                              color: AppColors.streakDebt, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Streak debt: ${streak.debt} day(s) — log extra sessions to clear it.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.streakDebt,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Recent Sessions ─────────────────────────────────────────────────
          if (history.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                'Recent Sessions',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            ...history.take(3).map((h) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _RecentSessionCard(entry: h),
                )),
          ],

          // ── Reminders ───────────────────────────────────────────────────────
          if (hasReminders) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'Reminders',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            _ReminderBox(
              icon: Icons.music_note_outlined,
              title: 'Practice Reminders',
              itemWidgets: practiceReminders
                  .map((r) => _PracticeReminderRow(item: r))
                  .toList(),
            ),
            const SizedBox(height: 10),
            _ReminderBox(
              icon: Icons.event_outlined,
              title: 'Calendar Reminders',
              itemWidgets: calendarReminders
                  .map((r) => _CalendarReminderRow(item: r))
                  .toList(),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Reminder box (expandable card) ────────────────────────────────────────────

class _ReminderBox extends StatefulWidget {
  final IconData icon;
  final String title;
  final List<Widget> itemWidgets;

  const _ReminderBox({
    required this.icon,
    required this.title,
    required this.itemWidgets,
  });

  @override
  State<_ReminderBox> createState() => _ReminderBoxState();
}

class _ReminderBoxState extends State<_ReminderBox> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final count = widget.itemWidgets.length;
    final hasMore = count > 1;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
            child: Row(
              children: [
                Icon(widget.icon, size: 18, color: primary),
                const SizedBox(width: 8),
                Text(
                  widget.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (count > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Most urgent item — always shown
          if (count > 0) widget.itemWidgets.first,

          // Remaining items — shown when expanded
          if (_expanded && count > 1) ...[
            Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
            ),
            ...widget.itemWidgets.skip(1),
          ],

          // Empty state
          if (count == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                'All caught up!',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ),

          // See all / See less toggle
          if (hasMore) ...[
            Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
            ),
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _expanded
                          ? 'Show less'
                          : 'See all $count reminders',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: primary,
                    ),
                  ],
                ),
              ),
            ),
          ] else
            const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Practice reminder row ─────────────────────────────────────────────────────

class _PracticeReminderRow extends StatelessWidget {
  final PracticeReminderItem item;
  const _PracticeReminderRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_outlined,
              size: 16, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You haven't practiced ${item.displayName}",
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${item.daysSince}d since last practice',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Calendar reminder row ─────────────────────────────────────────────────────

class _CalendarReminderRow extends StatelessWidget {
  final CalendarReminderItem item;
  const _CalendarReminderRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = EventColors.fromValue(item.event.colorValue) ??
        theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.event.title,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  item.dueLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Readiness meter ───────────────────────────────────────────────────────────

class _ReadinessMeter extends StatelessWidget {
  final double score;
  const _ReadinessMeter({required this.score});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 5,
            backgroundColor: Theme.of(context).dividerColor,
            color: AppColors.indigoNavy,
          ),
          Text(
            '${score.round()}',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ── Streak display ────────────────────────────────────────────────────────────

class _StreakItem extends StatelessWidget {
  final dynamic streak;
  final bool isDark;
  const _StreakItem({required this.streak, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = streak?.current ?? 0;
    final hasDebt = streak?.hasDebt ?? false;
    final isActive = current > 0 && !hasDebt;
    final valueText = streak != null ? '${current}d' : '0d';

    return Column(
      children: [
        if (isActive)
          _GoldOutlinedText(
            text: valueText,
            style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ) ??
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
          )
        else
          Text(
            valueText,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
        const SizedBox(height: 2),
        Text(
          'Streak',
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _GoldOutlinedText extends StatelessWidget {
  final String text;
  final TextStyle style;
  const _GoldOutlinedText({required this.text, required this.style});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(
          text,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4.5
              ..color = AppColors.streakCrimson,
          ),
        ),
        Text(
          text,
          style: style.copyWith(color: AppColors.streakGold),
        ),
      ],
    );
  }
}

// ── Stat item ─────────────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Recent session card ───────────────────────────────────────────────────────

class _RecentSessionCard extends StatelessWidget {
  final dynamic entry;
  const _RecentSessionCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateStr = DateFormat('MMM d').format(entry.date.toLocal());

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.exerciseName,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '$dateStr  ·  ${entry.minutes} min  ·  ${entry.bpm} BPM',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
