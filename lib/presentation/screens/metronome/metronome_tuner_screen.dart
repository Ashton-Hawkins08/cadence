import 'package:flutter/material.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/presentation/screens/tuner/tuner_screen.dart';
import 'standard_metronome_screen.dart';

// ── Metronome | Tuner pager ───────────────────────────────────────────────────
//
// One nav destination, two tools — same layout language as the Stats screen's
// Overview / Categories & Exercises tabs. Swiping between them keeps both
// alive (the metronome keeps ticking while you check your tuning).

class MetronomeTunerScreen extends StatelessWidget {
  const MetronomeTunerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          toolbarHeight: 0,
          backgroundColor:
              isDark ? AppColors.darkSurface : AppColors.lightSurface,
          elevation: 0,
          bottom: TabBar(
            tabs: const [
              Tab(text: 'Metronome'),
              Tab(text: 'Tuner'),
            ],
            labelColor: theme.colorScheme.primary,
            indicatorColor: theme.colorScheme.primary,
            labelStyle: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        body: const TabBarView(
          children: [
            StandardMetronomeScreen(),
            TunerScreen(),
          ],
        ),
      ),
    );
  }
}
