import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/domain/services/analysis/mic_analysis_service.dart';

// One mic-analysis service per visit to the tuner screen. autoDispose stops
// the mic and kills the DSP isolate the moment the screen is left — the
// microphone must never run in the background.
final micAnalysisServiceProvider =
    Provider.autoDispose<MicAnalysisService>((ref) {
  final service = MicAnalysisService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});
