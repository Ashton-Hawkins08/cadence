import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/domain/validators/name_validator.dart';
import 'package:cadence/presentation/providers/cloud_provider.dart';
import 'package:cadence/presentation/providers/settings_provider.dart';
import 'package:cadence/presentation/providers/database_provider.dart';
import 'package:cadence/presentation/screens/settings/cloud_auth_form.dart';
import 'package:cadence/presentation/screens/shell/app_shell.dart';
import 'package:cadence/presentation/widgets/common/centered_scroll_page.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _nameKey = GlobalKey<FormState>();

  final _instrumentController = TextEditingController();
  final _instrumentKey = GlobalKey<FormState>();
  bool _saving = false;

  // Cloud availability is fixed for the app's whole run (set once in main()
  // before runApp), so reading it once here is safe and avoids recomputing
  // page indices on every rebuild.
  late final bool _cloudAvailable;
  late final int _namePageIndex;
  late final int _pageCount;

  @override
  void initState() {
    super.initState();
    _cloudAvailable = ref.read(cloudAvailableProvider);
    // Page order: Welcome, [Create Account], How It Works, Name, Instrument.
    _namePageIndex = _cloudAvailable ? 3 : 2;
    _pageCount = _cloudAvailable ? 5 : 4;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _instrumentController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage == _namePageIndex) {
      // Name page — validate before proceeding
      if (!_nameKey.currentState!.validate()) return;
    }
    if (_currentPage < _pageCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _finish() async {
    if (!_instrumentKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final firstName = NameValidator.sanitize(_firstNameController.text);
      final lastName = NameValidator.sanitize(_lastNameController.text);
      final instrument = NameValidator.sanitize(_instrumentController.text);

      await ref.read(settingsProvider.notifier).setFirstName(firstName);
      if (lastName.isNotEmpty) {
        await ref.read(settingsProvider.notifier).setLastName(lastName);
      }
      await ref.read(settingsProvider.notifier).setInstrument(instrument);
      await ref.read(settingsRepositoryProvider).completeOnboarding();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const AppShell(),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress dots
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pageCount, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == i
                          ? theme.colorScheme.primary
                          : theme.dividerColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _WelcomePage(onNext: _next),
                  if (_cloudAvailable)
                    _CreateAccountPage(onNext: _next, onSkip: _next),
                  _HowItWorksPage(onNext: _next),
                  _NamePage(
                    firstNameController: _firstNameController,
                    lastNameController: _lastNameController,
                    formKey: _nameKey,
                    onNext: _next,
                  ),
                  _InstrumentPage(
                    controller: _instrumentController,
                    formKey: _instrumentKey,
                    onFinish: _finish,
                    saving: _saving,
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

// ── Page 1: Welcome ────────────────────────────────────────────────────────────

class _WelcomePage extends StatelessWidget {
  final VoidCallback onNext;
  const _WelcomePage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return CenteredScrollPage(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            isDark
                ? 'assets/images/logo_dark_symbol.png'
                : 'assets/images/logo_light_symbol.png',
            width: 140,
            height: 140,
            errorBuilder: (_, __, ___) => Icon(
              Icons.music_note,
              size: 100,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Welcome to Cadence',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Your complete musician hub. Track progress, build consistency, and prepare for performance.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onNext,
              child: const Text('Get Started'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Page 2 (conditional): Create Account ──────────────────────────────────────
//
// Only included in the page list when Cadence Cloud is available (see
// _cloudAvailable in _OnboardingScreenState). Always skippable — cloud is a
// bonus layer over the local-first app, never a gate. Skipping or a
// successful sign-in/create-account both just advance to the next page.

class _CreateAccountPage extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onSkip;
  const _CreateAccountPage({required this.onNext, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return CenteredScrollPage(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.cloud_outlined,
              size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            'Back up your progress',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a free Cadence Cloud account to back up your practice '
            'data and pick up right where you left off on another device. '
            'You can always do this later from Settings.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 28),
          CloudAuthForm(onAuthenticated: onNext),
          const SizedBox(height: 4),
          TextButton(
            onPressed: onSkip,
            child: const Text('Skip for now'),
          ),
        ],
      ),
    );
  }
}

// ── Page 3: How It Works ───────────────────────────────────────────────────────

class _HowItWorksPage extends StatelessWidget {
  final VoidCallback onNext;
  const _HowItWorksPage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CenteredScrollPage(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How Cadence Works',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 32),
          _Step(number: '1', text: 'Add your exercises and categories'),
          _Step(
              number: '2',
              text:
                  'Log sessions in seconds — just pick, enter BPM and time, done'),
          _Step(number: '3', text: 'Set goal BPMs and track your progress'),
          _Step(
              number: '4',
              text: 'Stay consistent — your streak keeps you accountable'),
          _Step(
              number: '5',
              text: 'Check reminders so nothing gets neglected'),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onNext,
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String number;
  final String text;
  const _Step({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(text, style: theme.textTheme.bodyLarge),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Page 4: Name ───────────────────────────────────────────────────────────────

class _NamePage extends StatelessWidget {
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final GlobalKey<FormState> formKey;
  final VoidCallback onNext;

  const _NamePage({
    required this.firstNameController,
    required this.lastNameController,
    required this.formKey,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CenteredScrollPage(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What\'s your name?',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll use this to personalize your experience.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),
          Form(
            key: formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: firstNameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'First Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: NameValidator.validate,
                  onFieldSubmitted: (_) => onNext(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: lastNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Last Name (Optional)',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: NameValidator.validateOptional,
                  onFieldSubmitted: (_) => onNext(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onNext,
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Page 5: Instrument ─────────────────────────────────────────────────────────

class _InstrumentPage extends StatelessWidget {
  final TextEditingController controller;
  final GlobalKey<FormState> formKey;
  final VoidCallback onFinish;
  final bool saving;

  const _InstrumentPage({
    required this.controller,
    required this.formKey,
    required this.onFinish,
    required this.saving,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CenteredScrollPage(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Almost there!',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'What instrument or equipment do you practice with?',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),
          Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g. Snare, Trumpet, Mellophone',
                prefixIcon: Icon(Icons.music_note_outlined),
              ),
              validator: NameValidator.validate,
              onFieldSubmitted: (_) => onFinish(),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: saving ? null : onFinish,
              child: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text("Let's go"),
            ),
          ),
        ],
      ),
    );
  }
}
