<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/images/logo_dark_full.png">
    <source media="(prefers-color-scheme: light)" srcset="assets/images/logo_light_full.png">
    <img alt="Cadence — Complete Musician Hub" src="assets/images/logo_light_full.png" width="520">
  </picture>
</p>

<p align="center"><i>A native-timed, all-in-one practice engine for musicians — built with Flutter.</i></p>

<p align="center">
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white">
  <img alt="Dart" src="https://img.shields.io/badge/Dart-0175C2?logo=dart&logoColor=white">
  <img alt="Firebase" src="https://img.shields.io/badge/Firebase-FFCA28?logo=firebase&logoColor=black">
  <img alt="Platforms" src="https://img.shields.io/badge/Platform-Android%20%7C%20Windows-4B45D6">
</p>

Cadence is an all-in-one practice assistant for musicians, built with Flutter. It replaces a folder of disconnected tools — a metronome app, a tuner app, a practice log, a binder of sheet music — with one local-first workspace built around a single native-timed metronome engine, with an optional cloud layer when you want your progress to follow you across devices.

### Contents

- [Why Cadence](#why-cadence)
- [Core Features](#core-features)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)

---

## Why Cadence

Most practice tools solve one problem in isolation. Cadence ties them together: a metronome section roadmap can drive page turns in your sheet music, a tuner and tempo detector share the same microphone pipeline, and every practice session feeds the same stats and streak system. It's local-first by design — every feature above works fully offline, since rehearsal rooms have no signal to depend on — with an optional Cadence Cloud account when you want backup and continuity across devices.

---

## Core Features

**Metronome engine**
- Sub-millisecond timing via a dedicated native thread (Kotlin `AudioTrack` pool on Android, Win32 `waveOut` + `QueryPerformanceCounter` on Windows) — the UI thread only polls for display, so audio timing is immune to Dart GC pauses or frame jank
- Full time signature support, including compound and odd meters (5/8, 7/8, 11/8) with selectable beat groupings
- **Piece Builder**: multi-section roadmaps (measure ranges, each with its own tempo/signature) that the engine transitions through automatically during playback
- **Blind BPM Randomizer**: hides a random tempo within a configurable window around a locked base — trains tempo recognition by ear, hard-capped to a 1–300 BPM range with no override
- **Cognitive Break**: injects controlled micro-fluctuations and dropped beats into a background rehearsal pattern to build tempo resilience, timed against the same native clock as normal playback

**Tuner & Tempo Ear**
- Chromatic tuner using a YIN-based pitch detector (cents-accurate, note + octave display)
- Live tempo detection from ambient audio, including a mixed-meter solver that infers tempo from odd-grouping onset patterns (e.g. recognizing a 7/8 pulse instead of assuming even beats)
- Both run on a dedicated Dart isolate reading raw microphone PCM, with a software gain stage tuned for real-world (quiet, unprocessed) input levels

**Rehearsal Canvas**
- Attach sheet music images directly to an exercise; swipe through pages during a practice session
- Vector-based annotation layer (draw/erase directly on the page) that persists per exercise
- Optional auto page-turn: link a Piece Builder roadmap to a score so pages advance automatically as the metronome crosses measure boundaries

**Practice tracking**
- Exercise and category library with BPM history, goals, and progress
- Calendar view with practice reminders and streak tracking
- Local session history and stats — nothing here ever requires a network call

**Cadence Cloud** *(optional — signed out, every feature above still works exactly the same)*
- Email/password account via Firebase Auth, introduced during onboarding or anytime from Settings — never a gate to using the app
- One-tap backup and restore of your practice library (categories, exercises, BPM history, notes, calendar, and piece roadmaps) to Cloud Firestore
- Constant backup: a debounced listener on the local database pushes changes automatically a few seconds after they settle, so there's nothing to remember to tap
- Signing into an existing account restores your data immediately — on a fresh install, that means skipping onboarding's setup questions entirely once your profile comes back from the cloud
- Cross-device restore correctly rebuilds relationships even though each device assigns its own local row IDs: every row carries a stable UUID `syncId`, and restore walks tables in dependency order, remapping each parent's `syncId` to *this device's own* local ID before resolving its children's foreign keys — verified by tests that run backup and restore across two independent databases with deliberately mismatched local IDs, so a broken remap can't accidentally pass

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI framework | Flutter / Dart |
| State management | Riverpod |
| Persistence | Drift (SQLite), versioned schema migrations |
| Metronome audio | Native platform threads via `MethodChannel` (Kotlin on Android, C++ on Windows) — not a Dart `Timer` |
| Mic-based analysis | Dedicated Dart `Isolate` running pitch/tempo DSP off the UI thread |
| Sheet music storage | Local file storage with per-page vector annotation records |
| Cloud sync (optional) | Firebase Auth + Cloud Firestore, secured by per-user Firestore rules |
| Targets | Android, Windows desktop (iOS/macOS/Linux buildable from the same codebase) |

## Project Structure

```
lib/
├── core/              App-wide constants, theme, and design tokens
├── data/
│   ├── database/      Drift schema, tables, and migrations
│   └── repositories/  Data access layer between the database and the app
├── domain/
│   ├── models/        Plain data models
│   ├── services/      Business logic — metronome engine, audio analysis (pitch/tempo), cloud sync
│   └── validators/    Input validation
└── presentation/
    ├── providers/     Riverpod providers wiring state to the UI
    ├── screens/       One folder per feature (metronome, tuner, scores, calendar, stats, ...)
    └── widgets/       Shared, reusable UI components
```

Each feature screen owns its providers and widgets; shared logic (the metronome engine, DSP analyzers, database access, cloud sync) lives in `domain/` and `data/` so it isn't duplicated across screens.

## Getting Started

```bash
flutter pub get
flutter run
```

Requires the Flutter SDK (channel stable) and a connected device or emulator. Windows desktop builds require Visual Studio with the "Desktop development with C++" workload. Cadence Cloud is optional at runtime — the app builds and runs fully offline with no Firebase project configured; see `lib/firebase_options.dart` if you want to wire up your own.

<details>
<summary><b>A closer look:</b> spinning up the audio-analysis isolate</summary>

<br>

Pitch and tempo detection run on a dedicated `Isolate`, not the UI thread — a busy analysis frame can't drop a Flutter frame or compete with the metronome's own audio thread. The handshake below hands the worker a `SendPort` before a single PCM chunk is allowed to arrive:

```dart
// Worker isolate first, so no PCM chunk can arrive port-less.
_fromWorker = ReceivePort();
final ready = Completer<SendPort>();
_resultSub = _fromWorker!.listen((msg) {
  if (msg is SendPort) {
    ready.complete(msg);
  } else if (msg is List && msg.isNotEmpty) {
    switch (msg[0]) {
      case 'pitch':
        final freq = msg[1] as double;
        final clarity = msg[2] as double;
        // Below ~0.5 clarity YIN is reading room noise — show "no pitch"
        // rather than a jittering wrong note.
        if (!_noteCtrl.isClosed) {
          _noteCtrl.add(clarity >= 0.5
              ? NoteReading.fromFrequency(freq, clarity)
              : null);
        }
      case 'tempo':
        if (!_tempoCtrl.isClosed) {
          _tempoCtrl.add(TempoReading(
              msg[1] as double, msg[2] as int, msg[3] as double,
              msg.length > 4 ? msg[4] as double : 0));
        }
    }
  }
});
_isolate = await Isolate.spawn(
  _workerMain,
  _WorkerConfig(_fromWorker!.sendPort, mode.index, beatUnits),
  debugName: 'cadence-mic-analysis',
);
_workerPort = await ready.future;
```

Full source: [`lib/domain/services/analysis/mic_analysis_service.dart`](lib/domain/services/analysis/mic_analysis_service.dart)

</details>

<details>
<summary><b>A closer look:</b> remapping foreign keys across devices on restore</summary>

<br>

Local tables use SQLite auto-increment integer IDs for foreign keys, and those IDs are never the same across two devices. Every row's stable, global identity is its `syncId` — a UUID minted once at creation. Backup translates every foreign key to the referenced row's `syncId` before writing to Firestore; restore translates back, building a `syncId → this device's local ID` map for each table before resolving the next table's foreign keys against it:

```dart
final categoryLocal = <String, int>{};
for (final doc in (await _col('categories').get()).docs) {
  final d = doc.data();
  final syncId = d['syncId'] as String;
  final existing = await (db.select(db.categories)
        ..where((t) => t.syncId.equals(syncId)))
      .getSingleOrNull();
  if (existing == null) {
    final id = await db.into(db.categories).insert(CategoriesCompanion(
      syncId: Value(syncId),
      name: Value(d['name'] as String),
      // ...
    ));
    categoryLocal[syncId] = id; // this device's own ID, not the source device's
  } else {
    categoryLocal[syncId] = existing.id;
  }
}
// Exercises resolve categoryId through categoryLocal, not the raw cloud value:
categoryId: Value(categorySyncId != null ? categoryLocal[categorySyncId] : null),
```

Full source: [`lib/domain/services/cloud_sync_service.dart`](lib/domain/services/cloud_sync_service.dart)

</details>
