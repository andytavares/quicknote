# Capture

Two panels, both opened only when you press their shortcut ([decision 0005](../decisions/0005-nothing-pops-up-unasked.md)): quick capture (S04, `⌃⌥N`) and Save where you stopped (S09, `⌃⌥S`). Nothing appears on wake or unlock.

## Ways to capture

| How | What happens |
|---|---|
| Type, press `↵` | Saved. The type, due date and repeat come from [sorting-and-repeats.md](sorting-and-repeats.md). `⇧↵` adds a line. |
| Paste a link alone | Bookmark. The title line is the link's host (`www.apple.com`), the link is on the next line and in the note's URL. Nothing is fetched, so there is no page title; Quicknote works offline. |
| Drop files on the panel, or **Attach** | Files are copied into the note when it is saved. Images are read on this Mac (Vision, English, accurate) and the text is searchable. |
| `⌃⌥S`, fill **Done**, **Blocked**, **Next** | A note of type context titled `Where I stopped — <app>` with the three labelled lines. |

The panel reads the app (and site, in a supported browser) before it opens, so the context is where you were, not Quicknote.

## The panel

- **Context chip** (`Slack · #product-launch`): the app and site the note is saved with.
- **Type chip** (`Event · Mon 26 Oct, 10:00`): the detected type and due time, live. `⇥` moves to the next type (Note, To-do list, Task, Reminder, Event, Idea, Bookmark, Bug, then around). A type you chose stays; the due date is still read from the text.
- **Colour dot**: the note colour (default from Settings). **Project**: one project or none.
- **Pin to <app or site>**: shown only when there is a context. The note then shows on the edge only while that app or site is in front.
- **Esc** closes and keeps the draft (text, type, colour, files) for next time. A saved draft is cleared.

| Key | Action |
|---|---|
| `⌃⌥N` / `⌃⌥S` | Open the panel (change in Settings) |
| `↵` / `⇧↵` | Save / new line (Save where you stopped: `↵` in any field saves) |
| `⇥` | Next type |
| `Esc` | Close, keep draft |

Every control has an accessibility label and can be reached with the keyboard.

## What is saved

`NoteRepository.save` with: body, kind, due, `dueHasTime`, repeat, colour, default font, project, app, site, URL (the pasted link, else the page you were on), `pinnedToContext` (only with a context). Attachments are imported after the save. A timed event then opens "Add to Calendar?" ([calendar-and-brief.md](calendar-and-brief.md)). Reminders are scheduled by the edge, which watches the database.

Save where you stopped also shows, collapsed, the last stop saved for the same app, so returning to work is `⌃⌥S` and a glance.

## Code

- `Quicknote/Capture/CaptureFeature.swift:12` `showPanel`, `:23` `showSaveContext`: read context, then show the panel.
- `Quicknote/Capture/CaptureDraft.swift:32` `makeNote` (draft to note), `:26` `cycleKind`.
- `Quicknote/Capture/CaptureModel.swift:28` `save`.
- `Quicknote/App/KeyPanel.swift` the shared non-activating key panel; `Quicknote/Capture/CaptureView.swift` the layout.
- `Quicknote/Capture/StopNote.swift:19` `body` format; `StopModel.swift:12` last stop lookup; `StopView.swift`.
- `Quicknote/Attachments/AttachmentImporter.swift:7` `importFiles(_:toNoteId:)`; `ImageTextReader.swift:7` `text(inImageAt:)`.
- Tests: `QuicknoteTests/CaptureTests.swift`.

## Limits

- Bookmarks have the host as title, never the page title (no network, and the context does not carry the title).
- Image text is English only. Unreadable or non-image files are attached without text. A file that cannot be copied is skipped silently.
- Files dropped on the panel are copied on save; nothing is copied if you press Esc.
- The panel opens on the screen the mouse is on.

## Manual test checklist

- [ ] `⌃⌥N` in Slack: chip says Slack, Quicknote's other windows do not come forward.
- [ ] Same in a full-screen app: the panel floats over it and takes typing.
- [ ] "Call Mira tomorrow at 10" shows Event with time; `↵` saves, then "Add to Calendar?" appears.
- [ ] `⇧↵` adds a line; `⇥` cycles types and the choice stays while typing.
- [ ] Paste a link in Chrome: Bookmark titled with the host. Saved note has the URL.
- [ ] Esc, reopen with `⌃⌥N`: draft is still there. Save, reopen: empty.
- [ ] Drop a screenshot with text, save, search for a word in it: the note is found.
- [ ] Pin toggle is hidden when there is no app context.
- [ ] `⌃⌥S` in Xcode: fill three fields, `↵`; saved note is "Where I stopped — Xcode". Open again: last stop is listed, collapsed.
- [ ] Wake or unlock the Mac: nothing appears.
- [ ] Keyboard only and VoiceOver: every control is reachable and named.
