import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/presentation/screens/home/home_screen.dart';
import 'package:cadence/presentation/screens/log_session/log_session_screen.dart';
import 'package:cadence/presentation/screens/calendar/calendar_screen.dart';
import 'package:cadence/presentation/screens/stats/stats_screen.dart';
import 'package:cadence/presentation/screens/history/history_screen.dart';
import 'package:cadence/presentation/screens/manage/category_exercises_screen.dart';
import 'package:cadence/presentation/screens/archive/archive_screen.dart';
import 'package:cadence/presentation/providers/nav_provider.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  // 4 real screens — the manage tab (index 2) triggers a bottom sheet
  final List<Widget> _screens = const [
    HomeScreen(),
    LogSessionScreen(),
    CalendarScreen(),
    StatsScreen(),
  ];

  // Maps bottom nav index to _screens index (skip the manage tab at position 2)
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

    return Scaffold(
      body: AnimatedSwitcher(
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
