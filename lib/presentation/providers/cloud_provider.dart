import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/domain/services/cloud_sync_service.dart';
import 'database_provider.dart';

// ── Cadence Cloud availability ────────────────────────────────────────────────
//
// Cloud features are strictly OPTIONAL: the app is fully functional offline
// and signed out — rehearsal rooms have no signal, and the metronome must
// never depend on one. This provider is overridden at startup with the
// result of Firebase.initializeApp (main.dart); everything cloud-related in
// the UI hides itself when it is false (unsupported platform, init failure).
final cloudAvailableProvider = Provider<bool>((_) => false);

// The signed-in Firebase user, or null. Streams auth changes so the
// Settings account section switches between sign-in and account views live.
final authStateProvider = StreamProvider<User?>((ref) {
  if (!ref.watch(cloudAvailableProvider)) return Stream.value(null);
  return FirebaseAuth.instance.authStateChanges();
});

// CloudSyncService for the CURRENTLY signed-in user — null when signed out,
// so callers can't accidentally run a backup/restore with no account
// attached to it.
final cloudSyncServiceProvider = Provider<CloudSyncService?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;
  return CloudSyncService(db: ref.watch(databaseProvider), uid: user.uid);
});

// Same as cloudSyncServiceProvider's null-check, but reads
// FirebaseAuth.instance.currentUser directly instead of going through the
// authStateChanges() STREAM.
//
// Why this exists: immediately after CloudAuth.signIn()/createAccount()
// resolves, code that needs "am I signed in RIGHT NOW" (e.g. auto-restore
// right after a successful sign-in) cannot safely rely on
// cloudSyncServiceProvider — the stream event that updates it can lag
// slightly behind the sign-in call's own Future completing, so reading it
// immediately after can still see the pre-sign-in (signed-out) state and
// silently skip the restore. FirebaseAuth updates `currentUser`
// synchronously as part of completing the sign-in itself, so this has no
// such race. Everything NOT in that immediate post-auth window (Settings'
// backup/restore buttons, the account display) should keep using the
// reactive provider, which is what actually keeps the UI live-updated.
CloudSyncService? currentUserCloudSync(WidgetRef ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  return CloudSyncService(db: ref.read(databaseProvider), uid: user.uid);
}

// Thin wrapper so screens never import firebase_auth directly.
class CloudAuth {
  static Future<String?> signIn(String email, String password) =>
      _run(() => FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password));

  static Future<String?> createAccount(String email, String password) =>
      _run(() => FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password));

  static Future<void> signOut() => FirebaseAuth.instance.signOut();

  static Future<String?> sendPasswordReset(String email) =>
      _run(() => FirebaseAuth.instance.sendPasswordResetEmail(email: email));

  /// Runs an auth call and maps failures to a human sentence (null = success).
  static Future<String?> _run(Future<void> Function() op) async {
    try {
      await op();
      return null;
    } on FirebaseAuthException catch (e) {
      return switch (e.code) {
        'invalid-email' => 'That email address doesn\'t look right.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'Email or password is incorrect.',
        'email-already-in-use' =>
          'An account with that email already exists — try signing in.',
        'weak-password' => 'Password needs at least 6 characters.',
        'network-request-failed' =>
          'No connection — check your internet and try again.',
        'too-many-requests' =>
          'Too many attempts — wait a minute and try again.',
        _ => 'Sign-in failed (${e.code}). Try again.',
      };
    } catch (_) {
      return 'Something went wrong. Try again.';
    }
  }
}
