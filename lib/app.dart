import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/theme/app_theme.dart';
import 'package:cadence/presentation/providers/settings_provider.dart';
import 'package:cadence/presentation/screens/shell/app_shell.dart';
import 'package:cadence/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:cadence/presentation/providers/database_provider.dart';

final onboardingCompleteProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  if (await repo.isOnboardingComplete()) return true;

  // Self-heal: a device can end up with the completion flag false while a
  // real profile already exists — e.g. the app closed between saving the
  // instrument and flipping the flag, or (as happened during this feature's
  // own testing) the flag was reset directly. A user who already has a name
  // and instrument saved has plainly finished setup before; never replay
  // the welcome flow (and re-ask for a name/instrument it would just
  // overwrite) just because one flag lagged behind the real data.
  final settings = await ref.watch(settingsProvider.future);
  if (settings.firstName.isNotEmpty && settings.instrument.isNotEmpty) {
    await repo.completeOnboarding();
    return true;
  }
  return false;
});

class CadenceApp extends ConsumerWidget {
  const CadenceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Cadence',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      // Several screens (metronome BPM display, bottom nav labels) use large
      // or tightly-packed fixed layouts that aren't designed to reflow.
      // Uncapped system font scaling (accessibility "large text" settings)
      // is the main real-world cause of overflow on those screens, so clamp
      // it rather than redesigning every layout to survive 2–3x text.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3),
          ),
          child: child!,
        );
      },
      home: const _AppRoot(),
    );
  }
}

class _AppRoot extends ConsumerWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kIsWeb) return const _WebUnsupportedScreen();

    final onboardingAsync = ref.watch(onboardingCompleteProvider);

    return onboardingAsync.when(
      loading: () => const _SplashScreen(),
      error: (_, __) => const AppShell(),
      data: (complete) => complete ? const AppShell() : const OnboardingScreen(),
    );
  }
}

class _WebUnsupportedScreen extends StatelessWidget {
  const _WebUnsupportedScreen();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              isDark
                  ? 'assets/images/logo_dark_symbol.png'
                  : 'assets/images/logo_light_symbol.png',
              width: 100,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.music_note, size: 80),
            ),
            const SizedBox(height: 32),
            Text(
              'Cadence',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Cadence is a desktop app.\nPlease open it on Windows.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFFFFFF),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              isDark
                  ? 'assets/images/logo_dark_symbol.png'
                  : 'assets/images/logo_light_symbol.png',
              width: 140,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.music_note,
                size: 80,
                color: Color(0xFF1A237E),
              ),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(
              color: Color(0xFF1A237E),
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}
