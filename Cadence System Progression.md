
# STAGE 1 — Build the Brain

**Goal:** Prove the idea works.

### Technologies

- Python
- JSON files

### Features

✅ Create Instrument

✅ Create Categories

✅ Create Exercises

✅ Log Practice Session

✅ Store Notes

✅ Display Stats

Example:

```
Instrument: TenorsCategory: CrossoversExercise: HelicoptersMinutes: 15Current BPM: 160Notes:Keep elbows relaxed.
```

---

### Concepts to Learn

#### Python Dictionaries

```
exercise = {    "name": "Helicopters",    "highest_bpm": 180,    "minutes_practiced": 240}
```

#### Lists

```
exercises = []
```

#### Functions

```
def add_exercise():
```

#### JSON

```
import json
```

Save data:

```
json.dump(data, file)
```

---

### What Cadence Looks Like

```
1. Log Session2. View Stats3. Add Exercise4. Add Notes
```

Terminal only.

Ugly.

That's fine.

---

### Study Next

- Classes (OOP)
- File handling
- JSON

---

# STAGE 2 — Build the Database

**Goal:** Stop storing data in JSON.

### Technologies

- Python
- SQLite

### Features

✅ Everything from Stage 1

PLUS

✅ User Profiles

✅ Categories stored properly

✅ Search Exercises

✅ Reminder System

---

### Database Design

Tables:

```
UsersExercisesPracticeSessionsCategoriesEventsNotes
```

---

### Example

Exercise Table

```
IDNameCategoryHighest_BPMLast_Practiced
```

---

### Concepts to Learn

#### SQL

```
SELECT * FROM Exercises
```

#### SQLite

```
import sqlite3
```

#### CRUD

Create

Read

Update

Delete

---

### Study Next

- SQL
- Database relationships
- Flask basics

---

# STAGE 3 — Turn It Into a Website

**Goal:** Make Cadence accessible in a browser.

### Technologies

- Python
- Flask
- SQLite

### Features

✅ Login Screen

✅ Dashboard

✅ Log Session Button

✅ Exercise Management

✅ Notes

✅ Reminder System

---

### Structure

```
cadence/app.pydatabase.dbtemplates/static/
```

---

### Pages

```
HomeDashboardExercisesCalendarStats
```

---

### Example Route

```
@app.route("/")def home():    return render_template("index.html")
```

---

### Concepts to Learn

#### Flask

Routes

Templates

Forms

Sessions

---

### Study Next

- HTML
- CSS
- Jinja Templates

---

# STAGE 4 — Make It Feel Real

**Goal:** Create a polished user experience.

### Technologies

- HTML
- CSS
- JavaScript
- Flask

### Features

✅ 3-Tap Log Session

✅ Progress Dashboard

✅ Goal BPM Tracking

✅ Readiness Score

✅ Streak System

✅ Achievement System

---

### Example

Dashboard:

```
Cadence Score: 83%Practice Streak: 12 DaysUpcoming Events:Band Camp - 5 DaysNeeds Attention:Crossovers
```

---

### Concepts to Learn

#### JavaScript

Buttons

Forms

DOM Manipulation

---

#### CSS

Layouts

Responsive Design

Dark Mode

---

### Study Next

- APIs
- Authentication
- Hosting

---

# STAGE 5 — Cadence 1.0

**Goal:** Release something people can actually use.

### Technologies

- Flask
- SQLite/PostgreSQL
- HTML
- CSS
- JavaScript
- GitHub

### Features

### Must Have

✅ Notes

✅ Exercise Tracker

✅ Categories

✅ Reminders

✅ Goal Tracking

✅ Dashboard

✅ Calendar

---

### Future

✅ AI Practice Suggestions

Example:

```
You haven't practiced Crossovers in 8 days.Your BPM decreased 5 BPM.Suggested Session:15 min Crossovers10 min Sweeps20 min Show Music
```

---

### Dream Features

#### Director Mode

```
View AttendancePost AnnouncementsAssign VideosCreate Assignments
```

#### Section Groups

```
PercussionTrumpetsMellophonesWoodwinds
```

#### Excuse Requests

```
Request AbsenceReasonDirector Approval
```