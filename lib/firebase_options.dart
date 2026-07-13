import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

// Firebase project configuration for Cadence Cloud (project cadence-498ff).
//
// Hand-written equivalent of what `flutterfire configure` generates. Values
// come from the Firebase console app registrations:
//   • android — the com.cadencecmh.app client in google-services.json
//   • windows — the "cadence-desktop" WEB app registration (desktop builds
//     of the Firebase C++ SDK authenticate with the web client's config)
//
// These are CLIENT IDENTIFIERS, not secrets — they ship inside every
// released binary by design. Data protection comes from Firebase Auth plus
// Firestore security rules, never from hiding these strings.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'Cadence Cloud is not configured for $defaultTargetPlatform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB8ukMbBdC2MefkZ_6tMcpQEyCRjq_UtoU',
    appId: '1:238562404536:android:dd1f62e364120df49d6c4d',
    messagingSenderId: '238562404536',
    projectId: 'cadence-498ff',
    storageBucket: 'cadence-498ff.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyALsR-HrMC_7FEO7HpmcL5pIhACzMsj4rA',
    appId: '1:238562404536:web:13bf21866cc268a09d6c4d',
    messagingSenderId: '238562404536',
    projectId: 'cadence-498ff',
    authDomain: 'cadence-498ff.firebaseapp.com',
    storageBucket: 'cadence-498ff.firebasestorage.app',
  );
}
