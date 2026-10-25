# User guide

Quicknote lives in the menu bar. Every job below starts with a shortcut or a menu item. All shortcuts: [shortcuts.md](shortcuts.md).

## Getting started

1. Open Quicknote. It has no Dock icon; look for its icon in the menu bar.
2. The first launch shows a welcome window once. It lists the shortcuts and has **Open at login**, **Change shortcuts** and **Start**. It asks for no permissions.
3. Click the menu bar icon for the menu: New note, Hold to talk, Snap, New card, Search, Save where I stopped, Start meeting recording, Daily Brief, Open Library, Hide edge tabs for 1 hour, Settings, Check for updates, Quit.
4. Quicknote asks for a permission the first time a feature needs it, with a short explanation first. See [permissions.md](permissions.md).

Quicknote needs macOS 27 or later and no account. Settings: [settings and permissions](features/settings-and-permissions.md).

## Catch a thought

1. Press `⌃⌥N` in any app.
2. Type "Call Jonah tomorrow at 10" and press `↵`.

Quicknote picks a type (here an Event, tomorrow 10:00) and shows it in a chip. Press `⇥` to choose another type. `⇧↵` adds a line. `Esc` closes and keeps your draft.

More examples: `remind me at 6 to pick up the dry cleaning` is a Reminder. `bug: crash on launch` is a Bug. A pasted link is a Bookmark. `water plants every tue and thu` is a repeating task.

Drop files on the panel to attach them. Text in images is read on your Mac, so search finds it.

To save where you were working, press `⌃⌥S`, fill **Done**, **Blocked** and **Next**, and press `↵`.

Details: [capture](features/capture.md), [sorting and repeats](features/sorting-and-repeats.md).

## Talk instead of typing

1. Hold `⌃⌥K`.
2. Speak. Your words show live.
3. Let go. The note is saved and a "Saved" toast shows for about 4 seconds. **Undo** deletes it.

A hold under 0.3 seconds saves nothing. Voice is English, recognised on your Mac. The first use downloads Apple's speech model. Details: [voice](features/voice.md).

## Pin a note to an app or website

1. In the capture panel, turn on **Pin to <app or site>** (for example Slack or figma.com). It shows only when Quicknote knows where you were.
2. Open that app or site later. A card "For Slack" slides out with your pinned notes. Tick one to mark it done.

In other apps those notes hide. Turn the slide-out off in Settings › General (Pop up app and site notes). Site names in browsers need extra permissions; see [edge and context](features/edge-and-context.md).

## Get reminded

- Give a note a due date **and a time**. It sends a notification then, with **Done** and **Snooze 1 hour**, and slides out on the edge.
- On the edge, click a tab and pick **Snooze**: 15 minutes, 1 hour, This evening, Tomorrow morning or Next week.
- Notes wait as coloured tabs on the right edge of the screen. Hover to peek, click to open, drag left to take one off the edge (it stays in the Library).
- **Hide edge tabs for 1 hour** is in the menu.

Date-only notes never alert. Details: [reminders](features/reminders-and-brief.md), [edge and context](features/edge-and-context.md).

## Plan your day with the Daily Brief

Menu › Daily Brief. It lists today's events, tasks due today, overdue items and notes coming back. Check a task to complete it. Click a row to open the note. **Read aloud** speaks the brief. It opens only when you choose it. Details: [calendar and brief](features/calendar-and-brief.md).

## Add a note to your calendar

Give a note a due time. Quicknote asks "Add to Calendar?". Check the title, date, time, length and calendar, then press **Add event**, or **Keep as note only**. Nothing is added until you confirm. Later edits to the note update the event, and moving the event in Calendar moves the note. This needs full Calendar access.

## Record a meeting

1. Menu › Start meeting recording. Enter a title and choose **Record my microphone** and **Record Mac audio**.
2. Press **Record**. A small pill at the top of the screen shows time and levels. It never takes focus from your call.
3. Press `⌃⌥B` in any app to bookmark a moment. Use **Pause** and **Stop** on the pill.
4. After Stop, Quicknote saves the audio, writes the transcript (you as Me, others as Others), finds action items and writes a summary on your Mac. Press **Open** on the pill.

In the meeting window, click a transcript line to jump to it. Tick action items; they also appear as tasks in the Library. **Export** saves a summary, transcript, notes or audio. Summaries need Apple Intelligence. Details: [meetings](features/meetings.md).

## Take and mark up a Snap

1. Press `⌃⌥4` and drag a box around anything on screen. `Esc` cancels.
2. Choose **Mark up**, **Save to edge** or **Copy**.
3. In the editor pick a tool (arrow, line, box, diamond, circle, triangle, text, numbered step, highlight, blur) and drag. Type a caption, or hold `⌃⌥K` and speak it.
4. **Copy**, **Save PNG**, **Share**, or drag the PNG out to another app.

Snap needs Screen Recording. Details: [snap](features/snap.md), [tool keys](shortcuts.md#snap-editor).

## Make a card

Press `⌃⌥C`, or press **Make a card** in a note's toolbar. Pick a style (sticky, postcard, polaroid, lined, minimal, kraft), add emoji, stickers, photos, washi tape, extra notes and text, and export a square, story or wallpaper-size PNG. Cards are saved with the note, so you can edit them later. Details: [cards](features/cards.md), [canvas](features/canvas.md).

## Organise: types, projects, links, formatting

Open the Library from the menu. The sidebar has Inbox, one list per type, Meetings, Snaps, Cards, Sites and apps, your projects and Completed.

- **Types.** Change a note's type from the Type menu. The text is kept.
- **Projects.** **+ New project** in the sidebar. Right-click to rename or delete; deleting keeps the notes.
- **Links.** Type `[[` and part of a title, then press `↵`. The linked note shows a "Linked from" chip back.
- **Formatting.** `*bold*`, `_italic_`, `- ` for a list, `[] ` for a checkbox.
- **Style.** The **Aa** button sets colour and font.
- **Repeat.** Pick a preset or type `every tue and thu`.

Details: [library](features/library.md), [editor](features/editor.md), [notes, links and formatting](features/notes-links-formatting.md).

## Find anything

Press `⌃⌥F`, type, press `↵`. Search covers your notes, meeting transcripts, and file names and text read from images. Each word matches as the start of a word: `pric page` finds "pricing page". `⌘↵` shows the Library. Search never looks outside Quicknote. Details: [search](features/search-and-export.md#search-panel).

## Share

Snaps and cards have a **Share** menu: Messages, Mail, AirDrop, Slack, Copy image, Save as PNG and Export as Markdown. **Slack** copies the image and opens Slack; paste with `⌘V`. A note's toolbar **Share** sends its text or exports Markdown. Details: [sharing](features/sharing.md).

## Export or delete your data

Settings › Data:

- **Show in Finder** opens `~/Library/Application Support/Quicknote`.
- **Export everything** writes one Markdown file per note, with attachment folders.
- **Delete everything** asks you to type `DELETE`. It cannot be undone. Calendar events already created stay.

Details: [privacy](privacy.md), [search and export](features/search-and-export.md).
