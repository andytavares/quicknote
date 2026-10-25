# Voice (hold to talk)

Hold a shortcut, say it, let go. Your words become a note, sorted and saved, with a toast that can undo it.

## Using it

1. Hold `⌃⌥K` (change it in Settings › Shortcuts). A small panel appears at the top of the screen without taking focus from the app you are in.
2. Talk. Your words appear live with a level meter, and a chip shows the type Quicknote has picked so far, such as "Reminder · Today, 18:00".
3. Release. The note is saved with the app and site you were in, and a "Saved" toast shows for about 4 seconds. **Undo** deletes the note.

| What happens | Result |
|---|---|
| Hold shorter than 0.3 s | Cancelled silently, nothing saved |
| Release with no words recognised | Cancelled silently |
| Release before the permission or speech model is ready | Cancelled silently |
| Press again while the previous note is saving | Ignored |
| The note is an event | "Add to Calendar?" opens ([calendar](reminders-and-brief.md)) |
| Snap is waiting for a voice caption | The words go to Snap and no note is made |

## Your words stay on this Mac

Speech is recognised on-device with Apple's `SpeechAnalyzer` and `SpeechTranscriber`. Audio and text are never uploaded. The panel says "On this Mac". Nothing is recorded to disk: only the text is kept.

## How the type is picked

The transcript goes through `EntryClassifier`, the same as typed notes, so "remind me at 6 to pick up the dry cleaning" is a reminder and "Call Mira tomorrow at 10" is an event. The rules are in [sorting-and-repeats.md](sorting-and-repeats.md). Change the type later from the Type menu.

## Language, download and permissions

- English (US) only.
- The first time, macOS downloads the English speech model. The panel shows "Getting ready…" until it is installed. If the download fails the panel says so and nothing is saved.
- Microphone and Speech Recognition are asked at first use of the shortcut, through `Permissions.ensure`, not at launch.

## For other features

`LiveTranscriber` (`Quicknote/Voice/LiveTranscriber.swift:34`) is the one speech-to-text type. Meetings runs one for the microphone (`Speaker.me`) and one for Mac audio (`Speaker.others`).

```swift
let transcriber = LiveTranscriber(speaker: .me)
try await transcriber.start()              // installs the English model if missing; throws LiveTranscriberError
transcriber.append(buffer)                 // any thread; converted to the analyzer's format; ignored before start() returns
for await update in transcriber.updates {  // .partial(String) or .line(SpokenLine)
}
let lines = try await transcriber.finish() // [SpokenLine], spans in ms from start
await transcriber.cancel()                 // stop without waiting
```

- `MicrophoneCapture` (`MicrophoneCapture.swift:7`): `start(onBuffer:)` delivers `AVAudioPCMBuffer`s on an audio thread; `stop()`; `level(of:)` for a meter.
- Spans are `result.range` converted to milliseconds from the first buffer (`LiveTranscriber.span(of:)`, line 99). Feed buffers continuously; silence you skip shifts later spans.
- Voice captions for Snap: set `VoiceFeature.captionTarget` to a closure (`VoiceFeature.swift:4`) and reset it to `nil` afterwards.

## Code

- `Quicknote/Voice/VoiceFeature.swift:11` `startHoldToTalk` / `stopHoldToTalk`, called by the shortcut.
- `Quicknote/Voice/HoldToTalk.swift:67` `keyDown`, `:79` `keyUp`, `:99` `begin`, `:137` `finish`, `:153` `save`: the state machine (idle, starting, listening, finishing, saved or cancelled).
- `Quicknote/Voice/VoiceNote.swift:6` transcript to `Note`; `:21` the type chip.
- `Quicknote/Voice/MicrophoneSession.swift:14` microphone plus `LiveTranscriber` behind the `SpeechSession` protocol.
- `Quicknote/Voice/HoldToTalkHUD.swift:22` the panel, with VoiceOver announcements for each state.
- Tests: `QuicknoteTests/VoiceTests.swift`.

## Limits

- One hold at a time; one language; no punctuation editing (the transcriber adds its own).
- The frontmost app is read when the key goes down, so switching apps while talking does not change the note's context.
- A model download of unknown length keeps the key's hold waiting; releasing early cancels.

## Manual test checklist

Not run by the build, needs a Mac with a microphone.

- [ ] First use: both permission prompts appear, then "Getting ready…" while the model downloads, then listening.
- [ ] Hold, say "remind me at 6 to pick up the dry cleaning", release: reminder at 18:00, toast, note in Library with the app you were in.
- [ ] Undo in the toast removes the note.
- [ ] Say "Call Mira tomorrow at 10": Add to Calendar appears.
- [ ] Tap the shortcut quickly: nothing saved, no toast.
- [ ] Hold in silence: nothing saved.
- [ ] Turn Wi-Fi off after the model is installed: still works.
- [ ] VoiceOver announces Listening, Saving and Saved.
- [ ] Deny the microphone: no panel stays open.
