import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'firebase_options.dart';
import 'presentation/providers/cloud_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    // By default Flutter prints only the FIRST error with its full widget
    // trail and one-lines the rest — useless when hunting layout bugs across
    // a session. Force the full dump every time (debug builds only).
    FlutterError.onError = (details) =>
        FlutterError.dumpErrorToConsole(details, forceReport: true);
  }

  // Cadence Cloud is strictly optional: every feature works signed-out and
  // offline. If Firebase can't initialize (no network, unsupported
  // platform), cloud UI simply hides itself — the app never blocks on it.
  var cloudReady = false;
  if (!kIsWeb && (Platform.isAndroid || Platform.isWindows)) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      cloudReady = true;
    } catch (e) {
      debugPrint('Cadence Cloud unavailable: $e');
    }
  }

  runApp(ProviderScope(
    overrides: [cloudAvailableProvider.overrideWithValue(cloudReady)],
    child: const CadenceApp(),
  ));
}
