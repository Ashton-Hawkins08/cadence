import 'package:firebase_auth/firebase_auth.dart' show User;
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
              : _SignedInPanel(user: user),
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

// ── Signed-in panel: account row + backup/restore ─────────────────────────────

class _SignedInPanel extends ConsumerStatefulWidget {
  final User user;
  const _SignedInPanel({required this.user});

  @override
  ConsumerState<_SignedInPanel> createState() => _SignedInPanelState();
}

class _SignedInPanelState extends ConsumerState<_SignedInPanel> {
  bool _busy = false;
  DateTime? _lastBackupAt;
  DateTime? _lastRestoreAt;

  @override
  void initState() {
    super.initState();
    _loadTimestamps();
  }

  Future<void> _loadTimestamps() async {
    final sync = ref.read(cloudSyncServiceProvider);
    if (sync == null) return;
    final backup = await sync.lastBackupAt();
    final restore = await sync.lastRestoreAt();
    if (!mounted) return;
    setState(() {
      _lastBackupAt = backup;
      _lastRestoreAt = restore;
    });
  }

  String _relative(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _backup() async {
    final sync = ref.read(cloudSyncServiceProvider);
    if (sync == null || _busy) return;
    setState(() => _busy = true);
    try {
      await sync.backup();
      await _loadTimestamps();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backed up to Cadence Cloud.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Backup failed — check your connection and '
                'try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final sync = ref.read(cloudSyncServiceProvider);
    if (sync == null || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from Cloud?'),
        content: const Text(
            'Brings in anything backed up from your other devices — your '
            'newest edits always win, and nothing already on this device '
            'is ever deleted by a restore.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final count = await sync.restore();
      await _loadTimestamps();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restored $count record${count == 1 ? '' : 's'} '
            'from Cadence Cloud.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Restore failed — check your connection and '
                'try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
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
    if (!mounted) return;
    // Give the user an immediate chance to sign into a different account,
    // or continue on signed-out — mirrors the account step in onboarding.
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PostSignOutScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = _lastBackupAt != null
        ? 'Last backed up ${_relative(_lastBackupAt!)}'
        : 'Connected to Cadence Cloud';

    return Column(
      children: [
        ListTile(
          leading:
              const Icon(Icons.cloud_done_outlined, color: AppColors.success),
          title: Text(widget.user.email ?? 'Signed in'),
          subtitle: Text(subtitle),
        ),
        const Divider(height: 1),
        ListTile(
          leading: _busy
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(Icons.cloud_upload_outlined,
                  color: theme.colorScheme.primary),
          title: const Text('Back Up Now'),
          subtitle: const Text('Save your practice data to the cloud'),
          onTap: _busy ? null : _backup,
        ),
        const Divider(height: 1),
        ListTile(
          leading: Icon(Icons.cloud_download_outlined,
              color: theme.colorScheme.primary),
          title: const Text('Restore from Cloud'),
          subtitle: Text(_lastRestoreAt != null
              ? 'Last restored ${_relative(_lastRestoreAt!)}'
              : 'Bring in data backed up from another device'),
          onTap: _busy ? null : _restore,
        ),
        const Divider(height: 1),
        ListTile(
          leading: Icon(Icons.logout, color: theme.colorScheme.error),
          title: const Text('Sign out'),
          onTap: _busy ? null : _signOut,
        ),
      ],
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
