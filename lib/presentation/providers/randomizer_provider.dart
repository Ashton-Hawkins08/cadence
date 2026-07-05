import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/constants/app_constants.dart';
import 'metronome_provider.dart';

// ── Blind BPM Randomizer ──────────────────────────────────────────────────────
//
// Training mode: the app picks a random tempo within ±30 BPM of a locked
// baseline and hides the number behind a blacked-out block. The musician
// plays along by ear, deduces the speed, then taps the block to reveal it.
//
// The engine keeps ticking normally — this controller only decides WHAT the
// BPM is and whether the UI is allowed to show it. Keeping it out of
// MetronomeEngine means the audio path is untouched by training modes.

class RandomizerState {
  final bool enabled;

  /// The baseline the user locked in when enabling the mode. Re-rolls always
  /// draw from [baseBpm - range, baseBpm + range] — never from the current
  /// hidden tempo — so the window can't drift over repeated rolls.
  final int baseBpm;

  /// Whether the hidden tempo is currently visible (after a tap-to-reveal).
  final bool revealed;

  const RandomizerState({
    this.enabled = false,
    this.baseBpm = 100,
    this.revealed = false,
  });

  RandomizerState copyWith({bool? enabled, int? baseBpm, bool? revealed}) {
    return RandomizerState(
      enabled: enabled ?? this.enabled,
      baseBpm: baseBpm ?? this.baseBpm,
      revealed: revealed ?? this.revealed,
    );
  }
}

class RandomizerController extends StateNotifier<RandomizerState> {
  RandomizerController(this._ref) : super(const RandomizerState());

  final Ref _ref;
  final _rng = Random();

  /// Spec: exactly 30 below and 30 above the locked baseline.
  static const int range = 30;

  MetronomeEngine get _engine => _ref.read(metronomeEngineProvider);

  /// Locks the CURRENT engine tempo as the baseline and rolls the first
  /// hidden tempo.
  void enable() {
    final base = _engine.bpm;
    state = RandomizerState(enabled: true, baseBpm: base, revealed: false);
    _roll(base);
  }

  /// Restores the locked baseline tempo so the user gets back exactly what
  /// they started from.
  void disable() {
    if (!state.enabled) return;
    _engine.setBpm(state.baseBpm);
    state = state.copyWith(enabled: false, revealed: false);
  }

  /// New random tempo from the ORIGINAL baseline window; re-hides the value.
  void randomizeAgain() {
    if (!state.enabled) return;
    state = state.copyWith(revealed: false);
    _roll(state.baseBpm);
  }

  void reveal() {
    if (!state.enabled || state.revealed) return;
    state = state.copyWith(revealed: true);
  }

  void _roll(int base) {
    // Window clamped to the app's valid BPM range (a base of 20 can't go
    // below minBpm, a base of 290 can't exceed maxBpm).
    final lo = max(AppConstants.minBpm, base - range);
    final hi = min(AppConstants.maxBpm, base + range);
    var next = lo + _rng.nextInt(hi - lo + 1);
    // Never land on the tempo that's already playing — a roll that changes
    // nothing would be indistinguishable from a broken button.
    if (hi > lo && next == _engine.bpm) {
      next = next >= hi ? next - 1 : next + 1;
    }
    _engine.setBpm(next);
  }
}

final randomizerProvider =
    StateNotifierProvider<RandomizerController, RandomizerState>(
  (ref) => RandomizerController(ref),
);
