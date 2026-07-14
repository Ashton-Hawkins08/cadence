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
- [Why a Musician Needs This](#why-a-musician-needs-this)
- [Core Features](#core-features)
- [Full Feature Reference](#full-feature-reference)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)

---

## Why Cadence

Most practice tools solve one problem in isolation. Cadence ties them together: a metronome section roadmap can drive page turns in your sheet music, a tuner and tempo detector share the same microphone pipeline, and every practice session feeds the same stats and streak system. It's local-first by design — every feature above works fully offline, since rehearsal rooms have no signal to depend on — with an optional Cadence Cloud account when you want backup and continuity across devices.

Four questions drive every design decision: *What should I practice? Am I actually improving? Am I ready for this performance? What have I been neglecting?* Nothing in the app exists that doesn't answer one of those.

---

## Why a Musician Needs This

Not feature-for-feature's-sake — each one solves a specific practice problem.

- **Sub-millisecond native timing** — a metronome that isn't perfectly steady works against the exact skill it's supposed to build. If a musician spends months practicing "in time" against a click that secretly drifts or stutters under load, they're internalizing the metronome's own imprecision, not real time. Precision isn't a nice-to-have here; a "close enough" metronome defeats the tool's entire purpose.

- **Odd and compound meters (5/8, 7/8, 11/8, 6/8, ...)** — a large share of real repertoire — modern band and orchestral literature, film and game scores, anything with Balkan or progressive influence — isn't in 4/4. A metronome that only counts in four either locks a musician out of that music or forces ad-hoc manual counting, which is exactly the crutch a metronome is supposed to remove.

- **Piece Builder (multi-section tempo roadmap)** — real pieces change tempo and meter section to section; a single static BPM only rehearses one section faithfully at a time, with a manual reset at every boundary. A roadmap plays the tempo and meter map of the actual piece, so a full run-through can be practiced exactly as it will be performed, not stitched together from isolated fragments.

- **Blind BPM Randomizer** — it's easy to watch the beat indicator instead of actually feeling the tempo, a visual crutch that quietly evaporates the moment a metronome isn't in view — which is every real performance. Hiding the number forces the internal sense that's actually being trained.

- **Cognitive Break (controlled drift + dropped beats)** — a musician who has only ever practiced against a mechanically perfect click can come apart the moment a live ensemble's tempo naturally breathes, or a beat gets briefly buried in the mix. Deliberately unstable practice builds the recovery reflex that a perfectly steady click never asks for.

- **Tuner + Tempo Ear, built into the same tool** — pitch and tempo are the two feedback loops a musician needs constantly, not occasionally. Three separate apps means the tuner is the one that's *not* already open when a string goes flat mid-run-through — so in practice, it doesn't get used. Built into the same app as the metronome, it does.

- **Rehearsal Canvas (annotated sheet music + auto page-turns)** — flipping a physical page means stopping and taking a hand off the instrument, right when focus matters most; pencil marks are permanent and hard to revise as fingerings change. Digital annotation is easy to update, and auto page-turns tied to the metronome's own measure count mean hands never have to leave the instrument to keep the music moving.

- **Readiness score, BPM history, streaks** — "am I actually improving, or just spending time?" is hard to answer from memory alone. Objective BPM history over weeks answers the first question directly; a readiness score that blends goal progress, how recently each exercise was touched, and practice consistency turns "am I ready for Saturday?" into one number instead of a guess.

- **Calendar + per-exercise reminders** — it's easy to unconsciously favor the pieces that are already fun to play and let a struggling one quietly go three weeks untouched. Reminders on each exercise's own interval surface that neglect before a performance does.

- **Cadence Cloud backup** — practice history is real, irreplaceable data — months of BPM progress and session logs, gone with a lost or reset phone. Backup exists because losing that record shouldn't cost more than losing the device did.

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

## Full Feature Reference

The section above is the pitch; this is every screen and what it actually does, organized by navigation area. Expand any section.

<details>
<summary><b>Onboarding</b></summary>

<br>

- Welcome → (optional) Cadence Cloud account → how-it-works walkthrough → name → primary instrument
- The account step is always skippable — a "Skip for now" option is present, and declining or dismissing it changes nothing else about the flow
- Signing into an **existing** account here (not creating a new one) restores your data immediately and, if a profile comes back, skips straight past the remaining name/instrument/tutorial screens instead of re-asking
- A device that somehow reaches this flow with a name and instrument already saved locally never sees it a second time — the completion flag self-heals against the real data rather than trusting itself blindly

</details>

<details>
<summary><b>Home</b></summary>

<br>

- **Readiness Score** (0–100), blended from three weighted signals:
  - 40% goal progress — average of each exercise's progress toward its goal BPM (exercises with no goal set don't drag this down; the score is neutral at 50% when nothing has a goal yet)
  - 35% practice freshness — the share of exercises practiced within their own reminder window
  - 25% streak health — current streak length (capped at a week), reduced for any streak debt owed
- **Average BPM overall** and current **streak**, with a streak-debt callout ("log extra sessions to clear it") when applicable
- Reminders list for exercises overdue against their individual reminder-day setting
- A 5-step interactive tutorial card (Welcome → the 5 nav sections → create a category → add an exercise → done) for brand-new installs, auto-advancing as you complete each real action; dismissed permanently once finished or skipped, and never shown again if you signed into an account that already had data

</details>

<details>
<summary><b>Log Session</b></summary>

<br>

- Three taps to log a session: pick an exercise, enter BPM, enter minutes practiced, optional note — no separate summary screen, confirms and drops you back to Home immediately
- Updates the exercise's last/highest BPM, total minutes, times-practiced count, and last-practiced date in the same action

</details>

<details>
<summary><b>Manage</b></summary>

<br>

Opens a popup with three destinations:

- **Categories & Exercises** — create/rename/delete categories; add exercises with an optional goal BPM, initial BPM (for progress-percentage math), custom reminder interval, and optional sheet music / measure-tracked piece attachment
- **Practice History** — every logged session, grouped by date, capped at the 50 most recent (oldest silently rolls off — and is recorded for cloud sync exactly like a deletion, so it doesn't reappear on a restore)
- **Archive** — categories and exercises removed from active use; deleting a whole category bundles its exercises into one archived unit you can restore as a group, or restore/delete individually

</details>

<details>
<summary><b>Metronome</b></summary>

<br>

- BPM entry via text field, slider, or tap tempo (1–300 BPM, hard-capped)
- Every time signature from 1/4 through 6/4, plus compound (3/8, 6/8, 9/8, 12/8) and odd meters (5/8, 7/8, 11/8) with selectable accent groupings (e.g. 7/8 as 2+2+3, 2+3+2, or 3+2+2)
- Subdivisions (eighths, sixteenths, triplets) and an accent-first-beat toggle
- **Blind BPM Randomizer** — hides the running tempo within a range you set around a locked base; tap to reveal
- **Cognitive Break** — a timed background drill that injects small tempo drift and occasional dropped beats into the click pattern, then returns cleanly to the base tempo
- **Tempo Ear** (bottom sheet) — taps out a tempo from ambient sound picked up by the mic, including odd-meter recognition, and shows the detected BPM alongside its ×2 and ÷2 alternates since a tapped pulse is ambiguous between the beat and its subdivision
- **Piece Builder** — attach a multi-section tempo/signature roadmap to an exercise (see Scores & Pieces below)

</details>

<details>
<summary><b>Tuner</b></summary>

<br>

- Chromatic tuner, cents-accurate, covering roughly 40 Hz (E1 — 5-string bass / low cello range) to 2100 Hz (above violin/piccolo range)
- Live level meter and confidence gating so ambient room noise doesn't register as a false note

</details>

<details>
<summary><b>Scores & Pieces</b></summary>

<br>

Browsed by category → exercise, mirroring the Manage tree rather than its own separate list — a score or piece is always attached to an exercise, never standalone.

- **Rehearsal Canvas** (the score viewer) — swipe through sheet-music pages with pinch zoom; a vector annotation layer (pen, highlighter, stroke eraser, undo) draws directly on the page and is saved per page; a visibility toggle collapses the sheet to a minimal BPM/measure dashboard for audio-only practice; optional auto page-turns trigger at specific measure numbers as the metronome plays through a linked piece roadmap
- **Piece player** — plays a piece's full section roadmap (each section its own tempo/signature/subdivision), with a live stat card (BPM, time signature, current measure, section progress), a visual section timeline, and an optional one-measure count-in before the piece starts
- **Piece editor** — add, reorder, and delete sections; validates that measure ranges are contiguous before allowing a save

</details>

<details>
<summary><b>Calendar</b></summary>

<br>

- Multi-day events with a title, notes, and color
- Reminders per event: same day, 1 day before, 1 week before, or a custom date
- Month view shows events whose date range overlaps each day, not just single-day start dates

</details>

<details>
<summary><b>Stats</b></summary>

<br>

- Readiness score, average BPM, and streak history over time
- Per-category and per-exercise breakdowns of goal progress

</details>

<details>
<summary><b>Settings</b></summary>

<br>

- **Cadence Cloud** — sign in, create an account, or sign out; manual **Back Up Now** / **Restore from Cloud**, plus constant automatic backup once signed in (see below); entirely hidden if cloud is unavailable on this platform/build
- **Profile** — name and primary instrument
- **Practice** — default reminder interval for new exercises
- **Appearance** — light/dark theme
- **Your Stats** — lifetime totals at a glance
- **About** — in-app help & guide
- **Reset all data** — wipes local practice data; deliberately does not touch a cloud backup, so it can't be used to accidentally destroy a backup you'd want to restore from later

</details>

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
