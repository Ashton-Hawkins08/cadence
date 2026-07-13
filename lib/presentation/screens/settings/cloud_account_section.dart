import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/presentation/providers/cloud_provider.dart';
import 'package:cadence/presentation/screens/onboarding/post_signout_screen.dart';
import 'cloud_auth_form.dart';

// ── Cadence Cloud account section (Settings) ─────────────────────────────────
//
// Signed out → one tile that opens the sign-in sheet.
// Signed in  → account email + sign out.
// Cloud unavailable (unsupported platform / init failed) → renders nothing;
// the app never advertises a feature it can't deliver right now.

class CloudAccountSection extends ConsumerWidget {
  const CloudAccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (!ref.watch(cloudAvailableProvider)) return const SizedBox.shrink();
    final user = ref.watch(authStateProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'CADENCE CLOUD',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        Card(
          child: user == null
              ? ListTile(
                  leading: Icon(Icons.cloud_outlined,
                      color: theme.colorScheme.primary),
                  title: const Text('Sign in'),
                  subtitle: const Text(
                      'Back up your practice data and sync across devices'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showSignInSheet(context),
                )
              : Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.cloud_done_outlined,
                          color: AppColors.success),
                      title: Text(user.email ?? 'Signed in'),
                      subtitle: const Text('Connected to Cadence Cloud'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.logout,
                          color: theme.colorScheme.error),
                      title: const Text('Sign out'),
                      onTap: () => _signOut(context),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
            'Your data stays on this device. Cloud backup and sync pause '
            'until you sign in again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (confirmed != true) return;
    await CloudAuth.signOut();
    if (!context.mounted) return;
    // Give the user an immediate chance to sign into a different account,
    // or continue on signed-out — mirrors the account step in onboarding.
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PostSignOutScreen()),
    );
  }

  void _showSignInSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _SignInSheet(),
    );
  }
}

// ── Sign-in / create-account sheet ────────────────────────────────────────────

class _SignInSheet extends StatelessWidget {
  const _SignInSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sign in to Cadence Cloud',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Your practice data backs up securely and follows you '
            'across devices.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          CloudAuthForm(onAuthenticated: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}
