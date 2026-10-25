# Reminders, snooze and the Daily Brief

## When Quicknote alerts you

Only for things you put a time on, or snoozed. Nothing else ever alerts.

- A reminder, task, event or to-do list with a due date **and a time** alerts at that time (if it is still in the future and the note is open).
- A snoozed note alerts when the snooze ends. A snooze wins over the due time.
- Completed notes and date-only items never alert.

## Snooze choices

| Choice | Comes back at |
|---|---|
| 15 minutes | now + 15 minutes |
| 1 hour | now + 1 hour |
| This evening | 20:00 today. Hidden from 19:00 on |
| Tomorrow morning | 09:00 tomorrow |
| Next week | 09:00 on the coming Monday. Never today, even on a Monday |

Snoozing also puts the note back on the screen edge.

## Daily Brief

It opens only when you ask, from the menu ([decision 0005](../decisions/0005-nothing-pops-up-unasked.md)). Sections, in order:

1. **Events today**: all-day first, then by start time.
2. **Due today**: open tasks, reminders and to-do lists; timed ones by time, then untimed. Ones you completed today stay, struck through.
3. **Overdue**: open items due before today, oldest first.
4. **Coming back**: notes snoozed until later today, by time.

The headline counts open items and leaves out zeros, for example `2 events, 3 tasks, 1 overdue, 2 notes coming back`. An empty day reads `Nothing planned today`.

## Read-aloud

> Good morning. Today is Sunday, 25 October. You have 2 events: Brunch with Ana at 10 AM, Call with Mum at 4:30 PM. 2 tasks are due today: Pay rent at 3 PM, Water plants. 1 overdue: Renew passport.

Empty sections are skipped. Completed items are not read.

## Code

- Snooze choices: `QuicknoteKit/Sources/QuicknoteKit/Reminders/SnoozeOption.swift:14` (`SnoozeOption.options`), `:50` (`Note.snoozed`)
- Alert planning: `QuicknoteKit/Sources/QuicknoteKit/Reminders/ReminderPlanner.swift:24` (`plannedAlerts`), `:32` (`notesComingBack`)
- Brief data: `QuicknoteKit/Sources/QuicknoteKit/Reminders/DailyBrief.swift:85` (`DailyBriefBuilder.build`, `DailyBrief.headline`)
- Read-aloud: `QuicknoteKit/Sources/QuicknoteKit/Reminders/DailyBriefSpokenText.swift:5` (`DailyBrief.spokenText`)
- The app fills `BriefEvent` from EventKit and schedules `PlannedAlert`s as notifications.
