import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/presentation/providers/categories_provider.dart';
import 'package:cadence/presentation/providers/exercises_provider.dart';
import 'package:cadence/presentation/providers/tutorial_provider.dart';
import 'package:cadence/presentation/providers/database_provider.dart';
import 'package:cadence/presentation/screens/home/home_screen.dart';
import 'package:cadence/presentation/screens/log_session/log_session_screen.dart';
import 'package:cadence/presentation/screens/calendar/calendar_screen.dart';
import 'package:cadence/presentation/screens/stats/stats_screen.dart';
import 'package:cadence/presentation/screens/history/history_screen.dart';
import 'package:cadence/presentation/screens/manage/category_exercises_screen.dart';
import 'package:cadence/presentation/screens/archive/archive_screen.dart';
import 'package:cadence/presentation/screens/audit/practice_audit_screen.dart';
import 'package:cadence/presentation/providers/nav_provider.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final List<Widget> _screens = const [
    HomeScreen(),
    LogSessionScreen(),
    CalendarScreen(),
    StatsScreen(),
  ];

  int _screenIndex(int tabIndex) {
    if (tabIndex < 2) return tabIndex;
    return tabIndex - 1;
  }

  void _onTabTapped(int index) {
    if (index == 2) {
      _showManageSheet();
    } else {
      ref.read(navIndexProvider.notifier).state = index;
    }
  }

  void _showManageSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ManageSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navIndexProvider);
    final tutorialDone = ref.watch(tutorialCompleteProvider).valueOrNull ?? true;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeIn,
              switchOutCurve: Curves.easeOut,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: child,
              ),
              child: KeyedSubtree(
                key: ValueKey(currentIndex),
                child: _screens[_screenIndex(currentIndex)],
              ),
            ),
          ),
          if (!tutorialDone) const _TutorialCard(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: _onTabTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            activeIcon: Icon(Icons.add_circle),
            label: 'Log',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit_outlined),
            activeIcon: Icon(Icons.edit),
            label: 'Manage',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart_outlined),
            activeIcon: Icon(Icons.show_chart),
            label: 'Stats',
          ),
        ],
      ),
    );
  }
}

// ── Tutorial Card ─────────────────────────────────────────────────────────────

class _TutorialCard extends ConsumerStatefulWidget {
  const _TutorialCard();

  @override
  ConsumerState<_TutorialCard> createState() => _TutorialCardState();
}

class _TutorialCardState extends ConsumerState<_TutorialCard> {
  Future<void> _completeTutorial() async {
    await ref.read(settingsRepositoryProvider).completeTutorial();
    ref.invalidate(tutorialCompleteProvider);
  }

  @override
  Widget build(BuildContext context) {
    final step = ref.watch(tutorialStepProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    // Auto-advance when user completes an action
    ref.listen(categoriesProvider, (_, next) {
      final cats = next.valueOrNull ?? [];
      if (cats.isNotEmpty &&
          ref.read(tutorialStepProvider) == TutorialStep.createCategory) {
        ref.read(tutorialStepProvider.notifier).advance();
      }
    });
    ref.listen(exercisesProvider, (_, next) {
      final exs = next.valueOrNull ?? [];
      if (exs.isNotEmpty &&
          ref.read(tutorialStepProvider) == TutorialStep.createExercise) {
        ref.read(tutorialStepProvider.notifier).advance();
      }
    });

    final bool isInteractive = step == TutorialStep.createCategory ||
        step == TutorialStep.createExercise;
    final bool isDone = step == TutorialStep.done;

    final stepNumber = switch (step) {
      TutorialStep.welcome => 1,
      TutorialStep.navigation => 2,
      TutorialStep.createCategory => 3,
      TutorialStep.createExercise => 4,
      TutorialStep.done => 5,
    };

    final title = switch (step) {
      TutorialStep.welcome => 'Welcome to Cadence',
      TutorialStep.navigation => 'Your 5 Sections',
      TutorialStep.createCategory => 'Create a Category',
      TutorialStep.createExercise => 'Add an Exercise',
      TutorialStep.done => "You're All Set!",
    };

    final body = switch (step) {
      TutorialStep.welcome =>
        'Track practice sessions, build consistency, and hit your BPM goals.',
      TutorialStep.navigation =>
        'Home · Log (record sessions) · Manage (exercises & history) · Calendar · Stats.',
      TutorialStep.createCategory =>
        'Tap Manage → Categories & Exercises → ➕ (top right) to create your first category.',
      TutorialStep.createExercise =>
        'Tap your new category → ➕ to add your first exercise.',
      TutorialStep.done =>
        'Head to the Log tab whenever you finish a practice session.',
    };

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: step counter + skip
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Step $stepNumber of 5',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              if (!isDone)
                TextButton(
                  onPressed: () async {
                    ref.read(tutorialStepProvider.notifier).skip();
                    await _completeTutorial();
                  },
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Title
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: isDone ? primary : null,
            ),
          ),
          const SizedBox(height: 4),
          // Body
          Text(
            body,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 12),
          // Action row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isInteractive)
                Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Waiting for you…',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                )
              else if (isDone)
                ElevatedButton(
                  onPressed: _completeTutorial,
                  child: const Text('Finish'),
                )
              else
                ElevatedButton(
                  onPressed: () =>
                      ref.read(tutorialStepProvider.notifier).advance(),
                  child: const Text('Next'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Manage Sheet ──────────────────────────────────────────────────────────────

class _ManageSheet extends StatelessWidget {
  const _ManageSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
              child: Text(
                'Manage',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _ManageOption(
              icon: Icons.folder_outlined,
              label: 'Categories & Exercises',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context, _slide(const CategoryExercisesScreen()));
              },
            ),
            _ManageOption(
              icon: Icons.history_outlined,
              label: 'Practice History',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, _slide(const HistoryScreen()));
              },
            ),
            _ManageOption(
              icon: Icons.verified_outlined,
              label: 'Practice Audit Log',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, _slide(const PracticeAuditScreen()));
              },
            ),
            _ManageOption(
              icon: Icons.inventory_2_outlined,
              label: 'Archive',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, _slide(const ArchiveScreen()));
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  PageRouteBuilder _slide(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 280),
    );
  }
}

class _ManageOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ManageOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(
        label,
        style:
            theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
