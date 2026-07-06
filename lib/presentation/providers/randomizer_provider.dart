import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/constants/app_constants.dart';
import 'metronome_provider.dart';

// ── Blind BPM Randomizer ──────────────────────────────────────────────────────
//
// Training mode: the app picks a random tempo within ±range BPM of a locked
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

  /// Half-width of the roll window, user-adjustable (default ±30). A base of
  /// 120 with range 40 rolls from 80–160. The window is always clamped to
  /// the app's 1–300 BPM limits — the range can never bypass the cap.
  final int range;

  /// Whether the hidden tempo is currently visible (after a tap-to-reveal).
  final bool revealed;

  const RandomizerState({
    this.enabled = false,
    this.baseBpm = 100,
    this.range = 30,
    this.revealed = false,
  });

  RandomizerState copyWith(
      {bool? enabled, int? baseBpm, int? range, bool? revealed}) {
    return RandomizerState(
      enabled: enabled ?? this.enabled,
      baseBpm: baseBpm ?? this.baseBpm,
      range: range ?? this.range,
      revealed: revealed ?? this.revealed,
    );
  }
}

class RandomizerController extends StateNotifier<RandomizerState> {
  RandomizerController(this._ref) : super(const RandomizerState());

  final Ref _ref;
  final _rng = Random();

  static const int defaultRange = 30;

  MetronomeEngine get _engine => _ref.read(metronomeEngineProvider);

  /// Locks the CURRENT engine tempo as the baseline and rolls the first
  /// hidden tempo. The previously chosen range is kept.
  void enable() {
    final base = _engine.bpm;
    state = RandomizerState(
        enabled: true, baseBpm: base, range: state.range, revealed: false);
    _roll();
  }

  /// Restores the locked baseline tempo so the user gets back exactly what
  /// they started from.
  void disable() {
    if (!state.enabled) return;
    _engine.setBpm(state.baseBpm);
    state = state.copyWith(enabled: false, revealed: false);
  }

  /// User corrected the base and/or range mid-session (tapping the "Base
  /// 100 ±30" chip). Values are clamped to the app's BPM limits, then a
  /// fresh hidden tempo is rolled from the new window.
  void configure({required int baseBpm, required int range}) {
    if (!state.enabled) return;
    final base = baseBpm.clamp(AppConstants.minBpm, AppConstants.maxBpm);
    final r = range.clamp(1, AppConstants.maxBpm - 1);
    state = state.copyWith(baseBpm: base, range: r, revealed: false);
    _roll();
  }

  /// New random tempo from the ORIGINAL baseline window; re-hides the value.
  void randomizeAgain() {
    if (!state.enabled) return;
    state = state.copyWith(revealed: false);
    _roll();
  }

  void reveal() {
    if (!state.enabled || state.revealed) return;
    state = state.copyWith(revealed: true);
  }

  void _roll() {
    // Window clamped to the app's valid BPM range: base 290 with range 20
    // rolls from 270–300, never past the 300 cap; a low base can't go
    // under minBpm either.
    final lo = max(AppConstants.minBpm, state.baseBpm - state.range);
    final hi = min(AppConstants.maxBpm, state.baseBpm + state.range);
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
