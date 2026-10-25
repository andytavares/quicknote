# Editor

The right pane of the Library (S10): text, toolbar, calendar sync and footer for one note. `NoteEditorView(noteId:)` is the only entry point; the Library embeds it and changes the id to switch notes (each id gets a fresh model).

## What you can do

**Type formatting** (styled live; the marks stay visible but faint)
- `*bold*`, `_italic_`, `- ` list items, `[] ` checkboxes, `[[Title]]` links. Rules: [notes-links-formatting.md](notes-links-formatting.md).
- Click a checkbox to tick it. Click a `[[link]]` chip to open that note in the Library. (Click does not place the cursor inside a chip; use the arrow keys.)

**Links and backlinks**
- Type `[[` and a partial title: a list of matching notes appears above the footer. Up/Down move, Return picks, Esc closes. The last row, `Create “…”`, makes a new note with that title and links to it.
- The footer shows "Linked from" chips for notes that link here; click to open.

**Toolbar**

| Control | What it changes |
|---|---|
| Type ▾ | `Note.kind` (Note, To-do list, Task, Reminder, Event, Idea, Bookmark, Bug). The body is kept. |
| Due date | `dueAt` and `dueHasTime`. Graphical date, "Add time" (9:00 default), Clear. |
| Repeat | `recurrence`. Presets, or free text read by `RecurrenceParser`, shown with `describe` and the next three dates; "Set repeat" applies it. |
| Priority | `priority` 0 to 3. |
| Aa | Style popover: 50 colour swatches (5 rows of 10; the six note colours first) plus "Custom colour…", and six fonts: Handwritten (Bradley Hand), System, Rounded, Serif (New York), Marker (Marker Felt), Mono. Sets `color` and `font`. A font missing on the Mac falls back to System. |
| Pin to <site or app> | `pinnedToContext`. Shown only when the note has a site or app. |
| Share | System share sheet with the text; "Export as Markdown…" saves the `.md` (see limits). |
| Make a card | `CardsFeature.newCard(fromNoteId:)`. |
| Delete | Confirmation; with a Calendar event it asks whether to delete the event too. |

**Calendar**
- Event note with a Calendar copy: changing its title, time or repeat calls `CalendarBridge.updateEvent`.
- Event note without a copy: setting a time opens `CalendarConfirmation.present` (the "Add to Calendar?" panel, never an automatic write).
- Changing the type away from Event, when a copy exists, asks "Also remove from Calendar?" (Remove from Calendar / Keep the event / Cancel).

**Footer**
- Attachments: chips open the file with its default app; the x removes it. Drop files onto the text to attach them through `AttachmentImporter.importFiles`.
- Action items show "From <meeting> at mm:ss", opening `MeetingsFeature.open`.

## How it works

| Piece | Entry point |
|---|---|
| View | `NoteEditorView` (`Editor/NoteEditorView.swift:5`) |
| State, saving, calendar, `[[` flow | `NoteEditorModel` (`Editor/NoteEditorModel.swift`): `save` (`:66`), `syncCalendar` (`:76`), `changeKind` (`:88`), `deleteNote` (`:104`), `updateLinkTrigger` (`:132`), `chooseSuggestion` (`:147`), `observeChanges` (`:183`) |
| Debounced save (0.5 s, flushed on disappear) | `SaveDebouncer` (`Editor/SaveDebouncer.swift:16`) |
| Styling, checkboxes, chip clicks, file drops | `EditorTextView.restyle` (`Editor/EditorTextView.swift:15`), `draw` (`:67`), `mouseDown` (`:103`), `performDragOperation` (`:130`) |
| NSTextView wrapper and Up/Down/Return/Esc | `NoteTextView` (`Editor/NoteTextView.swift`) |
| `[[` detection | `LinkTrigger.detect` (`Editor/LinkTrigger.swift:10`) |
| Calendar rules | `CalendarEditPolicy` (`Editor/CalendarEditPolicy.swift:7`, `:12`, `:19`) |
| Repeat presets and preview | `RepeatPreset`, `RepeatPreview.make` (`Editor/RepeatPreset.swift:41`) |
| Palette and fonts | `EditorPalette.swatches` (`Editor/EditorPalette.swift:6`), `EditorFont.resolve` (`Editor/EditorFont.swift:21`); `AppSettings.fontChoices` reads the font list |

Flow: keystroke -> `textDidChange` -> `model.edit` (debounce) -> `NoteRepository.save` -> `syncCalendar`. Toolbar changes go through `model.update`, which saves at once. `observeChanges` adopts newer versions of the note from the database (for example Calendar sync) unless there is unsaved typing.

## Limits

- Link chips and checkbox boxes are drawn over styled text; right-to-left layouts are untested.
- The `[[` list sits at the bottom of the text area, not at the caret, and is a SwiftUI overlay rather than an NSPopover so the text view keeps focus.
- Share uses SwiftUI `ShareLink` (the same system picker as `NSSharingServicePicker`).
- Export as Markdown writes the file where you choose and, when the note has attachments, a folder named like the exported file next to it. Rename the file and the attachment links break.
- Keeping the Calendar event after changing the type leaves `calendarEventId` set, so changing back to Event resumes syncing.
- The whole text is restyled on every keystroke; fine for note-sized text.

## Manual test checklist

- [ ] Type `*bold*`, `_italic_`, `- item`, `[] todo`: styled, marks faint; click the box ticks and unticks.
- [ ] Type `[[`: list opens; Up/Down/Return picks; Esc closes; `Create “…”` makes and links a note.
- [ ] Click a `[[link]]` chip: Library opens the target. The target shows this note under "Linked from".
- [ ] Type menu: each kind; the body stays.
- [ ] Due date with and without time, Clear; Repeat presets and `every tue and thu` (words plus three dates), Set repeat; Priority.
- [ ] Style: each of the 50 swatches, Custom colour, all six fonts.
- [ ] Pin to <site> appears only on notes with a site or app.
- [ ] Share sheet; Export as Markdown with and without attachments.
- [ ] Event note with a Calendar copy: edit the title, change the time, set a repeat (event updates). Change type to Task: question appears; try Remove and Keep. Delete: both options.
- [ ] Event note without a copy: set a time, the "Add to Calendar?" panel appears.
- [ ] Drop a file on the text: chip appears; click opens it; x removes it.
- [ ] Type, then switch notes within 0.5 s: the text is saved.
- [ ] VoiceOver and Tab reach every toolbar control.
