import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/presentation/providers/cloud_provider.dart';

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
                      onTap: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Sign out?'),
                            content: const Text(
                                'Your data stays on this device. Cloud backup '
                                'and sync pause until you sign in again.'),
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
                        if (confirmed == true) await CloudAuth.signOut();
                      },
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 24),
      ],
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

class _SignInSheet extends StatefulWidget {
  const _SignInSheet();

  @override
  State<_SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends State<_SignInSheet> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _creating = false; // false = sign in, true = create account
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = _creating
        ? await CloudAuth.createAccount(email, password)
        : await CloudAuth.signIn(email, password);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email first, then tap this again.');
      return;
    }
    final error = await CloudAuth.sendPasswordReset(email);
    if (!mounted) return;
    setState(() => _error =
        error ?? 'Password reset email sent — check your inbox.');
  }

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
            _creating ? 'Create your account' : 'Sign in to Cadence Cloud',
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
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            onSubmitted: (_) => _busy ? null : _submit(),
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.indigoNavy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(_creating ? 'Create Account' : 'Sign In'),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                      _creating = !_creating;
                      _error = null;
                    }),
            child: Text(_creating
                ? 'Have an account? Sign in'
                : 'New here? Create an account'),
          ),
          if (!_creating)
            TextButton(
              onPressed: _busy ? null : _forgotPassword,
              child: const Text('Forgot password?'),
            ),
        ],
      ),
    );
  }
}
