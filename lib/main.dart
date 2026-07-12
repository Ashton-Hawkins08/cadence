import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    // By default Flutter prints only the FIRST error with its full widget
    // trail and one-lines the rest — useless when hunting layout bugs across
    // a session. Force the full dump every time (debug builds only).
    FlutterError.onError = (details) =>
        FlutterError.dumpErrorToConsole(details, forceReport: true);
  }
  runApp(const ProviderScope(child: CadenceApp()));
}
