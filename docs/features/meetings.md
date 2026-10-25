# Meetings

Logic for recorded meetings: storage, action items, export. Recording and the detail window are below.

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

## Recording a meeting (S17)

1. Menu bar › **Start meeting recording** (there is no global shortcut for starting; ⌃⌥B bookmarks while recording). A small sheet asks for a title and two switches: **Record my microphone** and **Record Mac audio (other people on the call)**.
2. **Record** starts. A pill floats at the top of the screen: red dot, title, elapsed time, a live level for each source, **Bookmark ⌃⌥B**, **Pause / Resume**, **Stop**. It never takes focus, so the call stays in front. VoiceOver announces Recording, Paused, Saving and Saved.
3. `⌃⌥B` from any app adds a bookmark at the current second and a "Bookmarked at 12:04" toast shows for 4 seconds. When no meeting is recording it does nothing. Labels are edited in the meeting window.
4. **Pause** stops audio, transcript and the clock together; the time you paused is not in the recording. **Stop** saves.

### What is captured

| Source | Speaker | How |
|---|---|---|
| Microphone | `me` | `MicrophoneCapture` |
| Mac audio (everything the Mac plays, except Quicknote) | `others` | `SystemAudioTap`: a Core Audio process tap in a private aggregate device |

Each source has its own `LiveTranscriber` and its own audio file (`RecordingSource`). Finished lines are saved as they arrive with `MeetingRepository.append`, so a crash keeps the transcript so far. Speech stays on this Mac ([voice](voice.md)).

### Where files go

`~/Library/Application Support/Quicknote/Attachments/meetings/<meetingId>/`: `me.caf` and `others.caf` while recording. On Stop they are mixed into `meeting.m4a` (`AVMutableComposition` plus `AVAssetExportSession.export(to:as:)`) and the two `.caf` files are deleted. `meeting.audioPath` is `meetings/<meetingId>/meeting.m4a`, or empty when the mix failed (the `.caf` files are then kept).

### After Stop

`finishing` runs in order: finish both transcribers, mix the audio, `MeetingRepository.finish` (duration, audio path, action-item tasks), then the summary. The pill shows each step, then "Saved" with **Open** and **Close**. Nothing opens by itself ([decision 5](../decisions/0005-nothing-pops-up-unasked.md)).

### Summaries

Written on this Mac with the system language model (`SystemLanguageModel.default`, `MeetingSummarizer`). The transcript is cut into chunks of whole lines that fit half the context window (`SummaryChunker`), each chunk is summarised, and the parts are combined into one summary stored with `setSummary`. When the model is not available (Apple Intelligence off or not supported) the summary stays empty, the pill says "No summary: on-device summaries are not available on this Mac", and the Summary tab says the same. Action items do not need the model.

### Mac audio permission

macOS shows its own prompt the first time the tap starts (`NSAudioCaptureUsageDescription`); there is no API to read the answer. If the first 3 seconds carry no sound, the pill shows "No Mac audio is coming through. Allow Quicknote under Screen & System Audio Recording." with **Open Settings**, and `Permissions.recordSystemAudioResult(allowed: false)` is stored. When sound arrives later the banner goes and the result becomes `true`. A quiet start is indistinguishable from a refusal, so the banner can appear on a call where nobody has spoken yet. Microphone and Speech Recognition are asked through `Permissions.ensure` when you press Record. If Speech Recognition is refused or the model cannot start, audio still records and the pill says there is no transcript for that source.

## Meeting window (S18)

`MeetingsFeature.open(meetingId:atMs:)` opens one window per meeting (opening it again seeks).

- Header: title, date, duration, **Export**.
- Player (`AVPlayer`): play or pause, a scrubber with a mark for each bookmark.
- Tabs: **Transcript** (rows with time and Me or Others; click a row to seek; the row at the playhead is highlighted and scrolled into view; the window opens at `atMs`), **Summary**, **Bookmarks (n)** (time link plus an editable label).
- **Action items** panel: the tasks from `MeetingRepository.actionItemTasks`; the checkbox completes or reopens the task; the time link seeks. **+ Add action item** makes a task linked to the current playhead.

### Export

Export opens a save panel named from the title and date (`MeetingExport.fileName`), for example `Weekly sync 2026-10-23 summary.md`.

| Menu item | File | Content |
|---|---|---|
| Summary (Markdown) | `<title> <date> summary.md` | title, date and duration, summary |
| Full transcript (.txt) | `<title> <date> transcript.txt` | `TranscriptExporter.plainText` |
| Notes and tasks (Markdown) | `<title> <date> notes.md` | `TranscriptExporter.markdown` |
| Audio (.m4a) | `<title> <date>.m4a` | copy of `meeting.m4a` |

`/`, `:` and `\` in a title become `-`.

## Recording code entry points

- `Quicknote/Meetings/MeetingsFeature.swift:12` `toggleRecording`, `:21` `bookmark`, `:24` `open`
- `Quicknote/Meetings/MeetingRecorder.swift:42` `start`, `:64` `begin`, `:98` `track` (transcriber per source), `:123` `togglePause`, `:131` `bookmark`, `:145` `stop`, `:169` `mixAudio`, `:184` `summarise`
- `Quicknote/Meetings/RecorderTimeline.swift:4` phases and elapsed time
- `Quicknote/Meetings/RecordingSource.swift:38` `receive` (audio thread: file, level, silence, transcriber)
- `Quicknote/Meetings/SystemAudioTap.swift:22` `start`; `SilenceDetector.swift:5`
- `Quicknote/Meetings/RecorderPill.swift:53` the pill; `StartMeetingView.swift` the sheet
- `Quicknote/Meetings/MeetingSummarizer.swift:11`, `SummaryChunker.swift:5`, `MeetingAudioMixer.swift:11`
- `Quicknote/Meetings/MeetingWindow.swift:9`, `MeetingModel.swift`, `MeetingView.swift:5`; `TranscriptNavigator.swift:10`; `MeetingExport.swift:25`
- Tests: `QuicknoteTests/MeetingRecorderTests.swift`

## Limits

- English only, like voice notes.
- Mac audio is one stereo mix of all apps except Quicknote. Sound you hear through headphones is still captured, but a Bluetooth headset that switches to its call profile can change the sample rate or drop audio mid-meeting; the tap follows the default output when the meeting starts, not when you change it later.
- Your own voice heard through speakers is picked up by both sources, so it can appear as Me and as Others.
- The two sources start a few tens of milliseconds apart; transcript times are not aligned beyond that.
- Pausing shifts nothing: both files and the clock leave out paused time together.
- If writing the audio file fails, the audio already saved is kept and later audio is left out of the file; the transcript keeps going. The file is opened once per recording, so it is never overwritten.
- The summary of a very long meeting combines chunk summaries in one pass; it is not split again.
- Bookmark labels are edited in the meeting window, not in the pill.

## Manual test checklist

Not run by the build, needs a Mac with a microphone and a call or video playing.

- [ ] Start meeting recording: sheet shows title and both switches; Record is disabled with both off.
- [ ] First run: Microphone, Speech Recognition and the Mac audio prompt appear.
- [ ] Pill floats, does not take focus from the call, levels move for both sources.
- [ ] `⌃⌥B` from another app shows the toast; with no recording nothing happens.
- [ ] Pause: levels freeze, the clock stops; Resume continues without a gap in the transcript times.
- [ ] Mute Mac audio output for the first 3 seconds with Mac audio on: fix-it banner shows and Open Settings opens Screen & System Audio Recording; playing sound clears it.
- [ ] Stop: progress steps, then "Saved" with Open; `meeting.m4a` exists and the `.caf` files are gone.
- [ ] Summary appears with Apple Intelligence on; with it off, the pill and Summary tab say it is not available.
- [ ] Meeting window: click a transcript row seeks; current row highlights during playback; bookmark marks sit at the right places; edit a label; tick an action item; add one at the playhead.
- [ ] A task's link in the Library opens the meeting at its second.
- [ ] Each export saves with the expected name and content.
- [ ] VoiceOver reads the pill state and every control.
- [ ] Headphones and a Bluetooth headset: recording keeps going.
