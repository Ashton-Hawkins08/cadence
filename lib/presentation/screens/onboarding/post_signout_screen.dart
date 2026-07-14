import 'package:flutter/material.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/presentation/screens/settings/cloud_auth_form.dart';
import 'package:cadence/presentation/widgets/common/centered_scroll_page.dart';

/// Shown immediately after signing out from Settings. Gives the user a
/// direct chance to sign into a different account or create one — but
/// never blocks: "Continue without an account" always dismisses straight
/// back into the app, signed out, with all local data untouched.
class PostSignOutScreen extends StatelessWidget {
  const PostSignOutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: CenteredScrollPage(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.cloud_off_outlined,
                  size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 20),
              Text(
                "You've signed out",
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign back in to keep backing up your progress — or '
                'continue on. Your practice data stays right here on '
                'this device either way.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 28),
              CloudAuthForm(
                onAuthenticated: ({required wasSignIn}) =>
                    Navigator.of(context).pop(),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Continue without an account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
