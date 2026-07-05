import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Cognitive break UI state ─────────────────────────────────────────────────
//
// The break itself (variance generation, timing, expiry) lives entirely in
// MetronomeEngine — see startCognitiveBreak(). The only UI-owned state is the
// duration the user dialed in, which persists between activations within a
// session.

final cognitiveBreakDurationProvider =
    StateProvider<Duration>((_) => const Duration(minutes: 2));
