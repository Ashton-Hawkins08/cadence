import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    // By default Flutter prints only the FIRST error with its full widget
    // trail and one-lines the rest — useless when hunting layout bugs across
    // a session. Force the full dump every time (debug builds only).
    FlutterError.onError = (details) {
      // device_preview's own chrome (AnimatedSwitcher > LayoutBuilder in
      // device_preview.dart) throws this when a route pop and a provider-
      // driven rebuild land in the same frame. It's a false positive in the
      // package's internals, not app state corruption — log it instead of
      // red-screening over whatever the user is doing.
      if (details.exception.toString().contains('RenderLayoutBuilder was mutated')) {
        debugPrint('Ignored device_preview layout race: ${details.exception}');
        return;
      }
      FlutterError.dumpErrorToConsole(details, forceReport: true);
    };
    final defaultErrorBuilder = ErrorWidget.builder;
    ErrorWidget.builder = (details) {
      if (details.exception.toString().contains('RenderLayoutBuilder was mutated')) {
        return const SizedBox.shrink();
      }
      return defaultErrorBuilder(details);
    };
  }

  // Cadence is local-only: no accounts, no cloud sync, no network calls.
  runApp(ProviderScope(
    // DevicePreview wraps the UI in a picker that renders it inside real
    // device frames (iPhone 17, Pixel, etc.) for a quick screen-size sanity
    // check without booting an emulator. Debug-only — compiled out of
    // release builds via kDebugMode, so it never ships or costs anything.
    child: kDebugMode
        ? DevicePreview(
            // Off by default now that device-size sanity checks are done and
            // we're in pre-launch testing — its own chrome was intermittently
            // racing route transitions (see main()'s FlutterError.onError
            // above). Flip to true any time you want the device-frame picker
            // back; it's still fully compiled out of release builds either
            // way via kDebugMode.
            enabled: false,
            builder: (context) => const CadenceApp(),
          )
        : const CadenceApp(),
  ));
}
