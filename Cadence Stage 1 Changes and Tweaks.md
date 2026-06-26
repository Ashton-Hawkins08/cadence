

----------------------------


Future Systems
------------------------------------------------------------------------------------

Dash Board

Imagine opening Cadence and immediately seeing:

```
Readiness Score: 82Practice Streak: 17Most Neglected:Crossovers (11 days)Upcoming Event:Band Camp (4 days)Weekly Practice:4h 12m
```

Instead of:

```
1. Categories2. Exercises3. Notes
```

This becomes the heartbeat of the app.

The menu should be underneath it, for perspective, the dashboard shoud 1/3 of the entire screen. So it should be 1/3 Dashboard and 2/3 Main Menu

---------------

The biggest Future Bug

Not code.

Design.

---

You're approaching:

```
1500+ lines
```

Soon:

```
2000+
```

Then:

```
3000+
```

If everything stays in one file:

```
cadence.py
```

you will eventually hate your life.

Before Stage 2 I'd seriously think about:

```
cadence.pycategories.pyexercises.pyhistory.pystreaks.pygoals.pysettings.py
```

Not because you need it now.

Because you're growing into the size where professional projects start splitting files.

---------------------------------------
At some point around stage 3-4: Being able to change the amount of days set for reminders is ideal
Current:

```
"reminder_days": 3
```

hardcoded.

I like the idea.

But eventually:

```
Sweeps → 2 daysShow Music → 1 dayWarmups → 5 days
```

will matter.


-----------------------------------------------------------