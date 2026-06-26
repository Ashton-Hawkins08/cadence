# Cadence

Cadence is a musician-focused practice management platform designed to help students organize their practice, track progress, stay accountable, and prepare for performances through one centralized system.

Created by Ashton Hawkins, a marching band percussionist and aspiring AI Security Engineer, Cadence was built to solve a problem that many musicians experience but few tools fully address.

Throughout my years in band, I found myself constantly switching between multiple applications just to stay organized. One app tracked practice sessions. Another handled reminders. Notes were stored somewhere else. Calendars lived in a different program. Progress tracking was often nonexistent, and many practice tools felt disconnected from the way real students actually prepare for performances.

Rather than continuing to juggle several different platforms, I decided to build a solution myself.

Cadence began as a simple Python project focused on exercise tracking, but quickly evolved into something much larger. Features that once would have required multiple separate applications are now integrated into a single platform. Practice logs, BPM tracking, goal progression, notes, reminders, categories, practice streaks, exercise archives, performance statistics, and readiness analytics all work together as part of one system designed specifically for musicians.

The goal of Cadence is not simply to record practice sessions. The goal is to help musicians understand their habits, identify neglected fundamentals, monitor long-term growth, and stay prepared for rehearsals, auditions, competitions, and performances.

## Current Features

Custom instruments and exercise tracking, BPM progression and performance analytics, practice history and session logging, goal setting and progress monitoring, practice streak and accountability systems, category organization and management, exercise-specific notes, smart reminder systems, archive and recovery systems, statistical reporting and readiness tracking, user customization and settings.

## Why Cadence Is Different

Many existing music tools focus on one specific task. A metronome helps keep time. A notes app stores information. A calendar tracks events. A habit tracker records consistency.

Cadence combines these concepts into a single platform built around the way musicians actually practice. Instead of managing several disconnected applications, users can organize their entire musical development in one place.

## About The Developer

My name is Ashton Hawkins, and I am a marching band percussionist, technology student, CyberPatriot competitor, and PCAP Certified Associate Python Programmer.

Cadence represents the intersection of two passions that have shaped my high school experience: music and technology.

What started as a way to improve my own practice habits became an opportunity to learn software development, problem-solving, project design, and user-focused engineering. Every version of Cadence reflects lessons learned through testing, iteration, and continuous improvement.

This project is part of my journey toward a future career in cybersecurity, artificial intelligence, and software engineering.

---

## How to Run

```
python cadence_v1_8.py
```

No installs. No dependencies. Just Python 3 and a terminal.

---

## What's New in V1.8

V1.8 is a usability pass. The goal was simple: make the interface clear enough that anyone — regardless of age or computer experience — can use Cadence without confusion.

| Change | Details |
|---|---|
| **Every Yes/No question rewritten** | All `(y/n)` prompts replaced with a friendly Yes/No system. Accepts `yes`, `y`, `yeah`, `yep`, `sure`, `ok`, or `no`, `n`, `nope`, `nah` — case doesn't matter. Typing something unclear just asks again instead of guessing |
| **Menu wording simplified** | "0. Back / Cancel" → "0. Go Back". "0. Quit" → "0. Exit Cadence". "Choose #" → "Type the number". "Choose:" → "Type your choice:" |
| **Error messages rewritten in plain language** | "Must be at least 1" → "That number is too small. Please type 1 or higher." Name errors explain the actual problem instead of using technical terms |
| **Confirmations explain consequences before asking** | Permanent delete now tells you exactly what will be lost, then asks you to type the name to confirm — with a friendly "Phew!" if you cancel |
| **First-run instrument prompt gives examples** | "(For example: Snare, Tenors, Trumpet, Mellophone)" |
| **Log session prompts ask full questions** | "How many minutes did you practice?" instead of a bare label |
| **Archive collision menu clarified** | "Overwrite" now reads "Replace it (the old archived one will be deleted forever)" so the consequence is obvious before you choose |

### Bug Fix

| Fix | Details |
|---|---|
| **Category delete confirmation was case-sensitive** | While every other delete confirmation (archived exercises, archived categories) was already case-insensitive. Now consistent across the whole app — type the name in any casing to confirm |

---

## Full Menu Map

```
SPLASH SCREEN
  ↓
First-run: Enter Instrument
  ↓
Main Menu
├── 1. Log Practice Session
├── 2. Stats
│   ├── 1. View Exercise Stats        (Highest / Average / Recent BPM + goal progress)
│   ├── 2. View Category Stats        (weighted avg + each exercise inside)
│   └── 3. Overview — All Categories
├── 3. Reminders
│   ├── 1. View Active Reminders
│   ├── 2. Set Exercise Reminder Days
│   └── 3. Reset to Default
├── 4. Practice History               (last 50 sessions, display only)
├── 5. Manage Exercises
│   ├── 1. Add Exercise
│   └── 2. Edit Exercise
│       ├── 1. Rename
│       ├── 2. Change Category
│       ├── 3. Change Reminder Days
│       ├── 4. Set / Update Goal BPM
│       ├── 5. Clear Goal BPM
│       ├── 6. View Exercise Notes
│       │   ├── 1. Add Note
│       │   └── 2. Delete Note
│       └── 7. Archive This Exercise
├── 6. Manage Categories
│   ├── 1. Add Category
│   ├── 2. Rename Category
│   └── 3. Delete Category
├── 7. Archive
│   ├── 1. Restore Exercise
│   ├── 2. Permanently Delete Exercise
│   ├── 3. Restore Category
│   └── 4. Permanently Delete Category
└── 8. Settings & Info
    ├── 1. Change Instrument
    ├── 2. Reminder Settings
    ├── 3. App Statistics              (includes Goals Beaten)
    ├── 4. About Cadence
    └── 5. Help & Guide
```

---

## Name Rules (exercise and category)

| Rule | Detail |
|---|---|
| Cannot be blank | Empty or whitespace-only input rejected |
| Cannot be a plain number | `0`, `1`, `99` — collide with menu navigation |
| Cannot be `cancel` | Reserved word for aborting number prompts |
| Max 40 characters | Longer names rejected with character count shown |
| Case-insensitive | `Sweeps`, `SWEEPS`, `sweeps` are all the same |
| Whitespace normalised | Internal runs of spaces collapsed to one; leading/trailing stripped |
| Unicode safety | Unrenderable control characters rejected with a plain explanation |

---

## BPM Spike Warning

When you log a session, if the BPM you enter is 40 or more away from your last logged BPM for that exercise (jump up or drop down):

```
  ⚠️  BPM SPIKE WARNING!
  Your last log was 140 BPM.
  You just entered 185 BPM — that's a jump of +45.
  If this is a mistake, it will skew your average.
  Do you want to save it anyway? (Yes / No — press Enter for No):
```

Saying No cancels the session so you can re-enter the correct BPM.

---

## Goal BPM: Current vs Highest Progress

If your BPM has regressed since your best session, stats show both:

```
  Goal:          140 → 180 BPM
  Cur Progress:  [███░░░░░░░] 25%    ← based on last log (150 BPM)
  High Progress: [█████░░░░░] 50%    ← based on highest ever (160 BPM)
```

Goal BPM must always be strictly greater than your starting BPM. The prompt loops until you enter a valid value or type `cancel`.

---

## Goal Completion

When you reach 100% progress:

```
  🎉🎉  GOAL REACHED for 'Helicopters'!
  You hit your target of 180 BPM!
  Total goals beaten this session: 1

  1. Set a new, harder Goal BPM
  2. Remove the goal for now
  0. Keep things as they are
```

Each goal beaten increments the Goals Beaten counter visible in Settings → App Statistics.

---

## Date Guard

Cadence tracks a high-water mark of the latest date it has ever seen. If your system clock is wound backwards (accidentally or on purpose), Cadence detects it:

```
  ⚠️  DATE WARNING: Your system clock appears to have moved
  backwards (system says 2025-01-01, last recorded 2025-06-15).
  Using last known date 2025-06-15 to protect your streak and stats.
```

This prevents streak manipulation and protects log timestamps.

---

## Notes

Notes are attached to exercises, not a separate menu item.

**Session notes** (added during Log Practice Session) automatically attach to that exercise.

**Manual notes**: Manage Exercises → Edit Exercise → View Exercise Notes → Add Note.

Both types appear in the same place under the exercise, newest-first.

---

## Archive Collision Flow

If you try to create or rename something with the same name as an archived item:

```
  ⚠️  You already have an exercise with this name in your Archive.
  What would you like to do?
  1. Replace it (the old archived one will be deleted forever)
  2. Use a different name instead
  3. Don't make this exercise after all
```

---

## Stats: What Each BPM Field Means

| Field | Meaning |
|---|---|
| Highest BPM | The single highest BPM ever logged for this exercise |
| Average BPM | Mean of every BPM log — all sessions averaged together |
| Recent BPM | The BPM from your most recent session |

---

## Version History

| Version | Changes |
|---|---|
| V1.0 | Initial build |
| V1.2 | Avg BPM, Goal BPM, category reassignment, archive, streak |
| V1.4 | Splash, settings center, split stats/reminders, help guide, category archive |
| V1.5 | Practice history, input validation, case-insensitive names, archive collision protection, weighted BPM, goal cap, streak debt floor |
| V1.5.2 | Reserved name protection (digit-only, 'cancel') |
| V1.6 | Bug run — 10 confirmed bugs fixed |
| V1.7 | BPM spike warning, current/highest goal progress, goal completion flow, notes per-exercise, date guard, 40-char limit, unicode safety, archive collision menu, BPM range 1–500, history cap 50 |
| V1.7.2 – V1.7.3 | Two additional bug runs — recursion fix, stats display fixes, case-insensitive confirmations, orphaned category visibility |
| V1.8 | Full usability pass — Yes/No system replaces all y/n prompts, plain-language error messages, friendlier menu wording throughout |


---

© 2026 Ashton Hawkins — Cadence
Licensed under CC BY-NC 4.0. You may not use this project commercially.
https://creativecommons.org/licenses/by-nc/4.0/
