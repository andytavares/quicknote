# Meetings

Logic for recorded meetings: storage, action items, export. The recording UI section is added by the app unit.

## How a meeting is stored

```
note (kind .note, onEdge false, body = title)
  └─ meeting (noteId, title, startedAt, durationMs, audioPath, summary)
       ├─ transcriptSegment (startMs, endMs, speaker me|others, text)
       └─ meetingBookmark (atMs, label)

note (kind .task, sourceMeetingId, sourceMs, dueAt, onEdge true)   one per action item
```

- The microphone is recorded as `me`, Mac audio as `others`.
- `start` creates the note and the meeting. The note is off the edge so a meeting does not show as a tab.
- `append` adds finished `SpokenLine`s as segments. `durationMs` and `audioPath` are set by `finish`.
- Deleting the meeting note cascades to the meeting, segments and bookmarks. Tasks stay: they are separate notes.

## Action items

A sentence is an action item when it contains any of these (case-insensitive; curly apostrophes count):

`action item`, `to-do`, `todo`, `I'll `, `I will `, `we need to`, `can you `, `let's make sure`, or a capitalized name followed by ` will `.

| Sentence | Item? |
|---|---|
| Action item: Dana will send the revised estimate by Friday. | yes, text "Dana will send the revised estimate by Friday." |
| I'll book the room for the user test. | yes |
| Can you review the draft? | yes |
| Priya will own the launch. | yes |
| We talked about the weather. | no |
| It will rain tomorrow. | no (It, This, That, There, What, Who, Which are not names) |
| The tool will help us. | no (`tool` is not capitalized) |

- Segments are split into sentences. The item text drops a leading `Action item:`, is trimmed, and starts with a capital.
- The item time (`atMs`) is the start of its segment.
- Items whose letters and digits match (ignoring case and punctuation) are kept once.
- Due date: a weekday name (next such day after now), `tomorrow`, or `next week` (+7 days), each at the start of that day. Everything else has no due date. This is a small phrase table, not `NSDataDetector`: the detector cannot resolve relative dates against a given `now`, so results would change with the clock.
- With now = Sunday 25 Oct 2026, "by Friday" is 30 Oct 2026.

## Tasks link back to a second

`finish` saves each item as a `.task` note with `sourceMeetingId` and `sourceMs`. The app opens the meeting at that second. `finish` is idempotent: if the meeting already has tasks it returns them and creates none. A task's due date is `dueAt` with `dueHasTime` false.

## Export

`TranscriptExporter.plainText`: one line per segment, `[mm:ss]` (`[h:mm:ss]` from an hour on).

```
[18:32] Others: Action item: Dana will send the revised estimate by Friday.
[1:02:05] Me: Agreed.
```

`TranscriptExporter.markdown`: title, date and duration, then Summary, Bookmarks and Action items (each only when not empty), then the transcript.

```
# Design sync

2026-10-20 · 1:02:05

## Summary

Agreed to ship.

## Bookmarks

- [01:01] Pricing

## Action items

- [ ] Dana will send the revised estimate by Friday. ([18:32])

## Transcript

[18:32] Others: Action item: Dana will send the revised estimate by Friday.
[1:02:05] Me: Agreed.
```

## Code entry points

- `QuicknoteKit/Sources/QuicknoteKit/Meetings/MeetingRepository.swift:15` `MeetingRepository`; `finish` at `:57`
- `QuicknoteKit/Sources/QuicknoteKit/Meetings/ActionItemExtractor.swift:23` `actionItems(in:now:)`
- `QuicknoteKit/Sources/QuicknoteKit/Meetings/TranscriptExporter.swift:18` `plainText`, `:22` `markdown`
- `QuicknoteKit/Sources/QuicknoteKit/Meetings/MeetingTime.swift:4` `format(ms:)`, shared with the UI
