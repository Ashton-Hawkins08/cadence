import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
