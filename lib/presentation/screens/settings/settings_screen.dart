import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/constants/app_constants.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/data/repositories/settings_repository.dart';
import 'package:cadence/domain/validators/name_validator.dart';
import 'package:cadence/presentation/providers/exercises_provider.dart';
import 'package:cadence/presentation/providers/history_provider.dart';
import 'package:cadence/presentation/providers/settings_provider.dart';
import 'package:cadence/presentation/providers/streak_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (settings) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Profile ───────────────────────────────────────────────────
              _SectionHeader('Profile'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.person_outline,
                          color: theme.colorScheme.primary),
                      title: const Text('Name'),
                      subtitle: Text(
                        settings.lastName.isNotEmpty
                            ? '${settings.firstName} ${settings.lastName}'
                            : settings.firstName.isNotEmpty
                                ? settings.firstName
                                : 'Not set',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _editName(context, ref, settings),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.music_note,
                          color: theme.colorScheme.primary),
                      title: const Text('Instrument'),
                      subtitle: Text(settings.instrument),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          _editInstrument(context, ref, settings.instrument),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Practice ──────────────────────────────────────────────────
              _SectionHeader('Practice'),
              Card(
                child: ListTile(
                  leading: Icon(Icons.notifications_outlined,
                      color: theme.colorScheme.primary),
                  title: const Text('Default Reminder Days'),
                  subtitle: Text(
                      'Alert when not practiced for ${settings.defaultReminderDays} day(s)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _editReminderDays(
                      context, ref, settings.defaultReminderDays),
                ),
              ),

              const SizedBox(height: 24),

              // ── Appearance ────────────────────────────────────────────────
              _SectionHeader('Appearance'),
              Card(
                child: Column(
                  children: ThemePreference.values.map((pref) {
                    final label = switch (pref) {
                      ThemePreference.light => 'Light',
                      ThemePreference.dark => 'Dark',
                      ThemePreference.system => 'System Default',
                    };
                    final icon = switch (pref) {
                      ThemePreference.light => Icons.light_mode_outlined,
                      ThemePreference.dark => Icons.dark_mode_outlined,
                      ThemePreference.system =>
                        Icons.brightness_auto_outlined,
                    };
                    return RadioListTile<ThemePreference>(
                      value: pref,
                      groupValue: settings.themePreference,
                      onChanged: (v) {
                        if (v != null) {
                          // Defer to avoid _dependents.isEmpty assertion
                          // when theme change triggers a full tree rebuild
                          Future.microtask(
                            () => ref
                                .read(settingsProvider.notifier)
                                .setTheme(v),
                          );
                        }
                      },
                      title: Text(label),
                      secondary:
                          Icon(icon, color: theme.colorScheme.primary),
                      activeColor: theme.colorScheme.primary,
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 24),

              // ── App Stats ─────────────────────────────────────────────────
              _SectionHeader('Your Stats'),
              _StatsCard(settings: settings),

              const SizedBox(height: 24),

              // ── About ─────────────────────────────────────────────────────
              _SectionHeader('About'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.info_outline,
                          color: theme.colorScheme.primary),
                      title: const Text('Cadence'),
                      subtitle: const Text('Version 2.0.0'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.help_outline,
                          color: theme.colorScheme.primary),
                      title: const Text('Help & Guide'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showHelpSheet(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editName(
      BuildContext context, WidgetRef ref, AppSettings settings) async {
    final firstCtrl = TextEditingController(text: settings.firstName);
    final lastCtrl = TextEditingController(text: settings.lastName);
    final formKey = GlobalKey<FormState>();
    String? savedFirst;
    String? savedLast;

    // transitionDuration: Duration.zero ensures the dialog element tree is fully
    // deactivated before showGeneralDialog returns, preventing _dependents.isEmpty
    // assertions that fire when providers are mutated during a dialog exit animation.
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, _, __) => AlertDialog(
        title: const Text('Your Name'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: firstCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'First Name'),
                validator: NameValidator.validate,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: lastCtrl,
                textCapitalization: TextCapitalization.words,
                decoration:
                    const InputDecoration(hintText: 'Last Name (Optional)'),
                validator: NameValidator.validateOptional,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              savedFirst = firstCtrl.text.trim();
              savedLast = lastCtrl.text.trim();
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    firstCtrl.dispose();
    lastCtrl.dispose();

    if (savedFirst != null && context.mounted) {
      await ref.read(settingsProvider.notifier).setFirstName(savedFirst!);
      await ref.read(settingsProvider.notifier).setLastName(savedLast ?? '');
    }
  }

  Future<void> _editInstrument(
      BuildContext context, WidgetRef ref, String current) async {
    final ctrl = TextEditingController(text: current);
    final formKey = GlobalKey<FormState>();
    String? savedInstrument;

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, _, __) => AlertDialog(
        title: const Text('Your Instrument'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration:
                const InputDecoration(hintText: 'Guitar, Piano, Drums...'),
            validator: NameValidator.validate,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              savedInstrument = ctrl.text.trim();
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    ctrl.dispose();

    if (savedInstrument != null && context.mounted) {
      await _askResetStats(context, ref, savedInstrument!);
    }
  }

  Future<void> _askResetStats(
      BuildContext context, WidgetRef ref, String newInstrument) async {
    final reset = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, _, __) => AlertDialog(
        title: const Text('Reset Stats & Exercises?'),
        content: const Text(
          'Would you like to reset all exercises, categories, and stats along with the instrument change?\n\n'
          'Your name will be kept. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep Everything'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (!context.mounted) return;

    await ref.read(settingsProvider.notifier).setInstrument(newInstrument);

    if (reset == true && context.mounted) {
      await ref.read(settingsProvider.notifier).resetAllData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data reset. Fresh start!')),
        );
      }
    }
  }

  Future<void> _editReminderDays(
      BuildContext context, WidgetRef ref, int current) async {
    final ctrl = TextEditingController(text: current.toString());
    final formKey = GlobalKey<FormState>();
    int? savedDays;

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, _, __) => AlertDialog(
        title: const Text('Default Reminder Days'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(hintText: '1 – 365'),
            validator: (v) {
              final n = int.tryParse(v ?? '');
              if (n == null || n < 1 || n > AppConstants.maxReminderDays) {
                return 'Enter a number between 1 and ${AppConstants.maxReminderDays}.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              savedDays = int.parse(ctrl.text);
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    ctrl.dispose();

    if (savedDays != null && context.mounted) {
      await ref
          .read(settingsProvider.notifier)
          .setDefaultReminderDays(savedDays!);
    }
  }

  void _showHelpSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Help & Guide',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            ..._helpItems.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.$1,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(item.$2,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  static const _helpItems = [
    (
      'Logging a Session',
      'Tap Log in the bottom nav. Pick an exercise, enter duration and BPM, add an optional note, then confirm. Your streak and stats update automatically.'
    ),
    (
      'Exercises & Categories',
      'Add exercises from the Manage menu (pen icon). Each exercise can have a BPM goal — set a starting and target BPM to track your progress percentage. Group exercises into categories for better organization.'
    ),
    (
      'Archive',
      'Archiving removes an item from your active list without deleting it. To archive a piece or exercise, tap the three-dot menu and choose Archive. To restore or permanently delete, go to Archive in the Manage menu — it has tabs for exercises, category bundles, and pieces. Deleting a category archives all its exercises together as a bundle.'
    ),
    (
      'Metronome & Tuner',
      'Tap the metronome icon on the home screen. The first tab holds the metronome: set tempo by typing, sliding, or Tap Tempo; switch time signatures and subdivisions with the pickers. Swipe to the Tuner tab for the chromatic tuner — play a note and the needle shows how many cents sharp or flat you are (green = within 5¢).'
    ),
    (
      'Training Modes',
      'On the metronome page: Blind BPM Randomizer hides a random tempo within a window around your base — deduce it by ear, tap the black block to reveal, and tap the Base chip to change the base or range. Cognitive Break makes the click drift ±1–3 BPM and randomly drops beats for a duration you pick, so your inner pulse does the work instead of muscle memory.'
    ),
    (
      'Tempo Ear',
      'Also on the metronome page: play any steady beat near your device and Cadence detects its BPM live. Pick your time signature first — odd meters like 5/8, 7/8, and 11/8 are understood by listening for their long-short beat groups. The result is the quarter-note BPM you\'d dial into the metronome.'
    ),
    (
      'Scores & Pieces',
      'Sheet music and measure tracking belong to your exercises. When adding an exercise (Manage → Categories & Exercises → Add Exercise), switch on "Attach Sheet Music" to import score pages and/or "Measure Tracking" to design a piece map — sections with their own BPM, time signature, and measure range that the metronome follows automatically. Browse everything from the Scores & Pieces tab inside the metronome: each exercise shows whether a score, a piece, or both are linked.'
    ),
    (
      'Rehearsal Canvas',
      'Open an exercise\'s score to rehearse with the metronome on screen. Draw on your music with the pen and highlighter (annotations save automatically), pinch to zoom, and toggle sheet visibility for a minimal beat display. If a piece map is linked you can set auto page turns — the page flips itself at the measures you choose — or just swipe pages manually while it plays.'
    ),
    (
      'Compound & Asymmetric Time Signatures',
      '5/8 and 7/8 group eighth notes into beats (e.g. 2+3 or 2+2+3). "Eighths" mode clicks every eighth note. "Beats Only" mode clicks only the group onsets — useful for internalizing the pulse without subdivisions. 11/8 works the same way with three grouping options (3+3+3+2, 4+3+4, 2+3+3+3).'
    ),
    (
      'Calendar',
      'The calendar shows your practice days at a glance. Green dots mark logged sessions. Tap a day to see what you practiced. Use the Create Event button to schedule a future practice.'
    ),
    (
      'Streak',
      'Practice daily to build your streak. Missing a day adds debt (max 2). Two days of debt or a 2+ day gap resets your streak. Same-day extra sessions can burn off debt.'
    ),
    (
      'Readiness Score',
      'A composite score: 40% goal progress, 35% how recently you practiced, 25% streak health. It tells you how primed you are to perform.'
    ),
    (
      'Reminders',
      'The home screen flags exercises you haven\'t touched recently. Each exercise has its own reminder threshold — set it when editing the exercise.'
    ),
  ];
}

// ──────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: isDark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
class _StatsCard extends ConsumerWidget {
  final AppSettings settings;
  const _StatsCard({required this.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercises = ref.watch(exercisesProvider).valueOrNull ?? [];
    final history = ref.watch(historyProvider).valueOrNull ?? [];
    final streakAsync = ref.watch(streakProvider);
    final streak = streakAsync.valueOrNull;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _Row('Exercises tracked', exercises.length.toString()),
            _Row('Total sessions logged', settings.totalSessions.toString()),
            _Row('Total minutes practiced', settings.totalMinutes.toString()),
            _Row('Recent sessions shown', history.length.toString()),
            if (streak != null) ...[
              _Row('Current streak', '${streak.current} day(s)'),
              _Row('Best streak ever', '${streak.longest} day(s)'),
            ],
            _Row('Goals beaten', settings.goalsBeaten.toString()),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              )),
        ],
      ),
    );
  }
}
