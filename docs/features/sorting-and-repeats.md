# Sorting and repeats

Quicknote reads what you type and picks a type for it, a due date if there is one, and a repeat if you wrote one. You can always change the type from the Type menu; the body is never rewritten.

## What it does

| You type | You get |
|---|---|
| `https://www.figma.com/design/pricing-v3` | Bookmark |
| `bug: crash on launch` | Bug |
| `idea: a sticky note for URLs` | Idea |
| `- milk` and `- eggs` on two lines | To-do list |
| `remind me at 6 to pick up the dry cleaning` | Reminder, today 18:00 (tomorrow 18:00 if it is already past 18:00) |
| `remind me tomorrow to call Mom` | Reminder, tomorrow 09:00 |
| `Call Mira tomorrow at 10` | Event, tomorrow 10:00 |
| `Dentist on Nov 3` | Task, due 3 Nov 09:00, no time shown |
| `Buy milk` | Task, no due date |
| `water plants every tue and thu` | Task repeating "Weekly on Tuesday and Thursday" |
| `Lisbon was lovely` | Note |

## Rules, in order

The first rule that matches wins.

1. The text is only a URL (http or https, no spaces): bookmark.
2. Starts with `bug:` or `bug ` (any case): bug. Starts with `idea:`: idea.
3. Two or more lines, every non-empty line starting with `[]`, `[ ]`, `- [ ]` or `- `: to-do list.
4. Starts with `remind me`: reminder.
   - Time and no day: today, or tomorrow if that time has passed.
   - Day and no time: 09:00.
   - Neither: reminder with no due date.
5. Has a day and a time: event.
6. Has a day only: task due at 09:00, `hasTime` false (09:00 is a placeholder).
7. First word is a verb (`NLTagger` lexical class): task.
8. Otherwise: note.

Then, separately: a repeat phrase anywhere sets the repeat, and a note that would be a plain note becomes a task.

### Reading days and times

- Days: `today`, `tonight`, `tomorrow`, a weekday name (`Friday`, `next Friday`), `in 3 days`, `in 2 weeks`. A weekday always means the next one after today. Explicit dates such as `Nov 3` come from `NSDataDetector`; with no year, the next such date from today is used.
- Times: `10:30`, `3pm`, `at 10`, `noon`. With am/pm it is taken literally. A bare hour 1 to 6 means afternoon (`at 6` is 18:00); 7 to 11 is morning; 13 to 23 is 24-hour time.
- The repeat phrase is removed before reading days, so `every Monday` is not also a due date.

### Repeat phrases

`every day`, `daily`, `every weekday`, `every week`, `weekly`, `every 2 weeks`, `every other week`, `every 3 days`, `every month`, `monthly`, `every year`, `yearly`, `every tue and thu`, `every Monday, Wednesday and Friday`. Full and three-letter day names, any case. `RecurrenceParser.describe` turns a rule back into words: "Weekly on Tuesday and Thursday", "Every 2 weeks", "Every weekday".

### Finishing a repeating note

Completing a repeating note with a due date does not complete it: the due date moves to the next occurrence after now, and `completedAt` stays empty. The note is snoozed until that next occurrence, so it leaves the edge and comes back when it is due. Occurrences are found with calendar math, so a 09:00 note stays at 09:00 across the 1 Nov 2026 US clock change. An overdue note skips occurrences that are already past.

## Edge cases and known limits

- `NSDataDetector` cannot be told what "now" is, so relative words are read by `DateTimeReader` and the detector only handles explicit dates. Unusual phrasings ("the day after next") are not understood.
- A time with no day outside a reminder (`Standup at 10`) is not given a due date.
- A repeat phrase with no date leaves the due date empty, so completing that note just completes it. Only the first repeat phrase is read.
- The verb check follows the first word only; an imperative that `NLTagger` tags as a noun is a note.
- To-do lists need every non-empty line to be an item; a heading line above the items makes it a note or task.
- Monthly repeats on the 29th to 31st clamp to the end of shorter months, and the next one is counted from the clamped date.
- Weekly repeats with several weekdays and an interval above 1 (`every 2 weeks on Tue and Thu`) run both days in the same week, then skip.

## Code

- `QuicknoteKit/Sources/QuicknoteKit/Sorting/EntryClassifier.swift:20` `EntryClassifier.classify`, the rules above.
- `QuicknoteKit/Sources/QuicknoteKit/Sorting/DateTimeReader.swift:14` days; `:23` times.
- `QuicknoteKit/Sources/QuicknoteKit/Sorting/RecurrenceParser.swift:15` `find` (phrase and its range), `:10` `parse`, `:19` `describe`.
- `QuicknoteKit/Sources/QuicknoteKit/Sorting/RecurrenceRule.swift:21` `nextOccurrence`; `:47` `Note.recurrence`; `:61` `Note.completing`.
- Tests: `QuicknoteKit/Tests/QuicknoteKitTests/` (`EntryClassifierTests`, `RecurrenceParserTests`, `RecurrenceRuleTests`, `NoteCompletionTests`).
