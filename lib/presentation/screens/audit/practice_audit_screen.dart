import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/data/database/app_database.dart';
import 'package:cadence/domain/services/audit_log_service.dart';
import 'package:cadence/presentation/providers/metronome_provider.dart';

// ── Practice Audit Log screen ─────────────────────────────────────────────────
//
// Director-facing view of the tamper-evident session ledger:
//   • integrity banner (hash chain verified / broken at entry #N)
//   • aggregate stats (sessions, minutes, distinct days, day streak)
//   • the session list, newest first, each with its hash prefix
//   • "Copy Report" → plain-text report on the clipboard

final auditSessionsProvider = StreamProvider<List<AuditSession>>((ref) {
  return ref.watch(auditLogServiceProvider).watchSessions();
});

final chainVerificationProvider = FutureProvider<ChainVerification>((ref) {
  // Re-verify whenever the session list changes.
  ref.watch(auditSessionsProvider);
  return ref.watch(auditLogServiceProvider).verifyChain();
});

class PracticeAuditScreen extends ConsumerWidget {
  const PracticeAuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sessions = ref.watch(auditSessionsProvider);
    final verification = ref.watch(chainVerificationProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text('Practice Audit Log',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        centerTitle: true,
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Copy report',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () async {
              final report =
                  await ref.read(auditLogServiceProvider).buildReport();
              await Clipboard.setData(ClipboardData(text: report));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Report copied — paste anywhere')));
              }
            },
          ),
        ],
      ),
      body: sessions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (rows) => Column(
          children: [
            _IntegrityBanner(verification: verification, isDark: isDark),
            _StatsRow(rows: rows, isDark: isDark),
            const SizedBox(height: 4),
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'No sessions yet.\nEvery metronome session over '
                          '${AuditRecorder.minSessionSeconds}s is recorded '
                          'here automatically.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: rows.length,
                      itemBuilder: (_, i) =>
                          _SessionTile(row: rows[i], isDark: isDark),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Integrity banner ──────────────────────────────────────────────────────────

class _IntegrityBanner extends StatelessWidget {
  final AsyncValue<ChainVerification> verification;
  final bool isDark;
  const _IntegrityBanner({required this.verification, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return verification.when(
      loading: () => const SizedBox(height: 44),
      error: (_, __) => const SizedBox(height: 44),
      data: (v) => Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: (v.valid ? AppColors.success : AppColors.error)
              .withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: v.valid ? AppColors.success : AppColors.error,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              v.valid ? Icons.verified_outlined : Icons.gpp_bad_outlined,
              size: 20,
              color: v.valid ? AppColors.success : AppColors.error,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                v.valid
                    ? 'Hash chain verified — ${v.totalEntries} entries intact'
                    : 'CHAIN BROKEN at entry #${v.firstBrokenId} — records were altered',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: v.valid ? AppColors.success : AppColors.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Aggregate stats ───────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final List<AuditSession> rows;
  final bool isDark;
  const _StatsRow({required this.rows, required this.isDark});

  String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  int _dayStreak() {
    if (rows.isEmpty) return 0;
    final days = rows.map((r) => _dayKey(r.startedAt.toLocal())).toSet();
    var streak = 0;
    var cursor = DateTime.now();
    // Today counts if practiced; otherwise the streak may still be alive
    // from yesterday.
    if (!days.contains(_dayKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (days.contains(_dayKey(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalMin =
        (rows.fold<int>(0, (a, r) => a + r.seconds) / 60).round();
    final days =
        rows.map((r) => _dayKey(r.startedAt.toLocal())).toSet().length;

    Widget stat(String value, String label) => Expanded(
          child: Column(
            children: [
              Text(value,
                  style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.indigoNavySoft)),
              Text(label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  )),
            ],
          ),
        );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          stat('${rows.length}', 'Sessions'),
          stat('$totalMin', 'Minutes'),
          stat('$days', 'Days'),
          stat('${_dayStreak()}', 'Day Streak'),
        ],
      ),
    );
  }
}

// ── Session tile ──────────────────────────────────────────────────────────────

class _SessionTile extends StatelessWidget {
  final AuditSession row;
  final bool isDark;
  const _SessionTile({required this.row, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = row.startedAt.toLocal();
    final date =
        '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final time =
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    final minutes = (row.seconds / 60).toStringAsFixed(1);
    final bpmText = row.bpmLow == row.bpmHigh
        ? '${row.bpmLow} BPM'
        : '${row.bpmLow}–${row.bpmHigh} BPM';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$date  ·  $time  ·  ${minutes}m',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '$bpmText  ·  ${row.timeSignature}  ·  '
                  '⛓ ${row.entryHash.substring(0, 8)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.indigoNavySoft.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              row.mode,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.indigoNavySoft,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
