# Library

One window (S10) with a sidebar, a note list and the note editor. Open it from the menu bar (Open Library), from a search result, or from a note elsewhere in the app. It is reused if already open.

## Sidebar

| Row | Shows |
|---|---|
| Daily Brief | Opens the Brief window; the Library selection does not change |
| Inbox | Every open note except kind `context` |
| Tasks, Reminders, Events, Ideas, Bookmarks, Bugs | Open notes of that type |
| Meetings | Recorded meetings, newest first: title, date, duration. A click opens the meeting at 0:00 |
| Snaps, Cards | Gallery (below) |
| Places: Sites and apps | Notes with an app or site, grouped (below) |
| Projects | One row per project, in name order. "+ New project" adds one; right-click a project to rename or delete it (notes are kept) |
| Completed | Completed notes, any type |

Counts come from the same queries as the lists. A project's count includes its completed notes. Snaps and Cards count every canvas note of that kind.

## Note list

Colour stripe, title, and a grey line: type, then due date ("due Tue 28 Oct"), overdue in red ("overdue 2 days"), repeat, and the site or app. The circle completes a note (a repeating note moves to its next date; see sorting-and-repeats.md); in Completed it reopens. A task that came from a meeting action item shows a `mm:ss` link that opens the meeting at that second.

The toolbar has New note (opens the capture panel), Delete, and Search (opens the search panel, also Cmd-F).

## Task views

Tasks has a segmented control. Empty groups are hidden and notes keep the repository order (due date, then newest).

- **By due date**: Overdue, Today, This week, Later, No date. A date with a time is overdue once that time has passed; a date without a time is overdue after its day. This week is the rest of the calendar week (the calendar's first weekday) after today.
- **By project**: projects in name order, then No project.
- **By priority**: High, Medium, Low, No priority.

Reminders and Events group by due date. Ideas, Bookmarks, Bugs, Inbox, projects and Completed are flat lists.

## Sites and apps

`NoteRepository.contextGroups()`: one section per site (else app) with a letter badge, "n notes · app" or "n notes · site", and a row per note. Clicking a note opens it in its own section with the editor. Completed notes are included.

## Gallery

Snaps and Cards share one grid with a Snaps / Cards control. A note is a Snap when its canvas background is `.image`, a Card when it is `.card`; notes with no canvas, or an unreadable one, are in neither. Each cell shows the note's attachment of kind `.snap` named `preview.png` (a placeholder when missing), title and date. A click calls `SnapFeature.edit` or `CardsFeature.edit`. Newest first.

## Live updates

`LibraryView` runs `AppDatabase.noteChanges()` while the window is on screen and reloads the list, counts, projects and meetings on every note change. Meeting rows change only when a note changes too (starting a meeting adds a note); the list also reloads on every section switch.

## Keyboard

Arrow keys move in the sidebar and lists; Shift-arrow and Cmd-click multi-select. Backspace deletes the selection after a confirmation. Cmd-F opens search. Buttons, checkboxes and gallery cells are reachable with Tab when Full Keyboard Access is on, and all have accessibility labels.

## Code

- Entry points: `Quicknote/Library/LibraryFeature.swift:10` `show`, `:18` `open(noteId:)`.
- Window content: `LibraryView.swift:4`; sidebar `LibrarySidebar.swift:5`.
- Data and live updates: `LibraryModel.swift:37` `observe`, `:44` `reload`; actions (open, complete, delete, projects) `LibraryModel+Actions.swift:20`.
- Section to query: `LibrarySection.swift:67` `filter`; section for a note `:86` `containing`.
- Task grouping: `TaskGrouper.swift:26` `groups`, `:39` `isOverdue`; row text `TaskRowText.swift:6`.
- Views: `TaskListView.swift:5`, `SitesAndAppsView.swift:5`, `MeetingListView.swift:5`, `GalleryView.swift:6`; Snap or Card: `GalleryKind.swift:10`.
- Tests: `QuicknoteTests/LibraryTests.swift`.

## Limits

- Thumbnails load on the main thread with `NSImage(contentsOf:)`; fine for hundreds of Snaps, not thousands.
- Counts run one query per section on every note change.
- `open(noteId:)` puts a plain note, to-do list or context note in Inbox, and a canvas note in Inbox too (the gallery has no editor pane). A context note is not listed in Inbox, so it opens with nothing highlighted.
- Selecting a note that disappears from the current list (completed, deleted elsewhere) clears the selection.
- Deleting a note removes its rows at once; its attachment files (and a meeting's audio) are removed at the next launch by `AttachmentStore.removeOrphanedFiles`, called from `AppDelegate`.

## Manual test checklist

- [ ] Open Library from the menu twice: one window.
- [ ] Each sidebar row lists the right notes; counts match; Daily Brief opens the Brief.
- [ ] Add a note elsewhere: the list and count update without reopening.
- [ ] Tasks: switch the three groupings; overdue is red; tick a task, a repeating task moves to its next date.
- [ ] A meeting action item shows mm:ss and opens the meeting.
- [ ] New project, rename, delete (notes stay, view returns to Inbox).
- [ ] Select two notes, press Backspace: confirmation, then both deleted.
- [ ] Sites and apps: click a note, it opens with the editor.
- [ ] Gallery: Snaps and Cards switch; missing preview shows a placeholder; click opens the editor.
- [ ] Search from a result opens the note in the right section.
- [ ] VoiceOver reads every control.
