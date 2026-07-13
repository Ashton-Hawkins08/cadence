import 'package:flutter/material.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/presentation/providers/cloud_provider.dart';

/// Shared Cadence Cloud sign-in / create-account fields — just the form
/// mechanics (no Scaffold, no heading), so the exact same validation and
/// error handling is embedded identically in three places: the Settings
/// sign-in sheet, the onboarding create-account page, and the post-sign-out
/// screen. Fixing a bug here fixes it everywhere at once.
class CloudAuthForm extends StatefulWidget {
  final VoidCallback onAuthenticated;
  const CloudAuthForm({super.key, required this.onAuthenticated});

  @override
  State<CloudAuthForm> createState() => _CloudAuthFormState();
}

class _CloudAuthFormState extends State<CloudAuthForm> {
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
      widget.onAuthenticated();
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
    setState(() =>
        _error = error ?? 'Password reset email sent — check your inbox.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
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
    );
  }
}
