class StreakState {
  final int current;
  final int longest;
  final int debt;
  final String? lastLogDate;
  final int logsToday;

  const StreakState({
    this.current = 0,
    this.longest = 0,
    this.debt = 0,
    this.lastLogDate,
    this.logsToday = 0,
  });

  StreakState copyWith({
    int? current,
    int? longest,
    int? debt,
    String? lastLogDate,
    int? logsToday,
  }) =>
      StreakState(
        current: current ?? this.current,
        longest: longest ?? this.longest,
        debt: debt ?? this.debt,
        lastLogDate: lastLogDate ?? this.lastLogDate,
        logsToday: logsToday ?? this.logsToday,
      );

  bool get hasStreak => current > 0;
  bool get hasDebt => debt > 0;
}

class StreakUpdateResult {
  final StreakState newState;
  final bool isNewRecord;

  const StreakUpdateResult({required this.newState, required this.isNewRecord});
}

class StreakService {
  StreakService._();

  // Exact port of Python's update_streak logic.
  static StreakUpdateResult update(StreakState state, String today) {
    // ── Same day as last log ──────────────────────────────────────────────────
    if (state.lastLogDate == today) {
      final newLogsToday = state.logsToday + 1;
      int newDebt = state.debt;
      // Extra sessions on same day chip away at debt
      if (newLogsToday > 1 && newDebt > 0) {
        newDebt = (newDebt - 1).clamp(0, 2);
      }
      return StreakUpdateResult(
        newState: state.copyWith(logsToday: newLogsToday, debt: newDebt),
        isNewRecord: false,
      );
    }

    // ── Different day ─────────────────────────────────────────────────────────
    int newCurrent = state.current;
    int newDebt = state.debt;
    const newLogsToday = 1;

    if (state.lastLogDate == null) {
      // First ever log
      newCurrent = 1;
      newDebt = 0;
    } else {
      final last = DateTime.parse(state.lastLogDate!);
      final now = DateTime.parse(today);
      // Build UTC midnights from local date components to avoid DST-day
      // rounding errors (a spring-forward day is only 23 h; inDays = 0
      // instead of 1, which would silently reset the streak).
      final lastUTC = DateTime.utc(last.year, last.month, last.day);
      final nowUTC = DateTime.utc(now.year, now.month, now.day);
      final gap = nowUTC.difference(lastUTC).inDays;

      if (gap == 1) {
        // Consecutive day — streak grows
        newCurrent += 1;
        if (newDebt > 0) newDebt = (newDebt - 1).clamp(0, 2);
      } else if (gap == 2 && state.debt < 2) {
        // Missed one day but debt allows it — streak survives, debt increases
        newDebt = (newDebt + 1).clamp(0, 2);
        newCurrent += 1;
      } else {
        // Missed too many days — streak resets
        newCurrent = 1;
        newDebt = 0;
      }
    }

    int newLongest = state.longest;
    final isNewRecord = newCurrent > newLongest;
    if (isNewRecord) newLongest = newCurrent;

    return StreakUpdateResult(
      newState: state.copyWith(
        current: newCurrent,
        longest: newLongest,
        debt: newDebt,
        lastLogDate: today,
        logsToday: newLogsToday,
      ),
      isNewRecord: isNewRecord,
    );
  }
}
