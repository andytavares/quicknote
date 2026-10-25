# Notes, links and formatting

Logic for notes, projects, `[[links]]`, Slack-style formatting and the edge filter. It lives in `QuicknoteKit` and has no UI.

## What you can do

- **Types.** Every note has a `NoteKind` (note, todoList, task, reminder, event, idea, bookmark, bug, context). Changing the type keeps the body.
- **Projects.** Create, rename and delete projects. Deleting one keeps its notes; they become project-less.
- **Links.** Type `[[Title]]` to link to another note. The linked note shows the linking note as a backlink. Typing `[[` offers title suggestions.
- **Formatting.** `*bold*`, `_italic_`, `- ` lists, `[] ` checkboxes.
- **App and site notes.** A note with `appBundleId` or `siteHost` appears on the Sites and apps screen (S16), grouped by site when it has one, else by app. If it is also pinned to its context, it shows on the edge only while that app or site is in front (S07).

## How it works

| Piece | Entry point |
|---|---|
| Save, delete, fetch | `NoteRepository.save` (`Notes/NoteRepository.swift:26`), `delete` (`:36`), `note(id:)` (`:40`) |
| Library lists (Inbox, type, project, completed) | `NoteRepository.notes(matching:)` (`:44`), `NoteListFilter` (`:4`) |
| Backlinks and `[[` suggestions | `backlinks(to:)` (`:51`), `linkSuggestions(prefix:limit:)` (`:63`) |
| Sites and apps screen | `contextGroups()` (`:76`) |
| Projects | `ProjectRepository` (`Notes/ProjectRepository.swift:4`) |
| Find `[[Title]]` in a body | `NoteLinkParser.linkedTitles(in:)` (`Notes/NoteLinkParser.swift:6`) |
| Style ranges for the editor | `SlackMarkdown.spans(in:)` (`Editor/SlackMarkdown.swift:24`) |
| Tick a checkbox | `SlackMarkdown.togglingCheckbox(in:line:)` (`Editor/SlackMarkdown.swift:35`) |
| What the edge shows | `EdgeFilter.visibleNotes` (`Notes/EdgeFilter.swift:16`), `contextNotes` (`:26`) |

Saving: `save` sets `updatedAt`, inserts or updates, then deletes the note's `noteLink` rows and recreates them from the parsed titles, all in one transaction.

Lists are ordered by due date (no date last), then newest `updatedAt`. Inbox is every open note except kind `context`.

Formatting: the editor applies `StyleSpan`s to an `NSTextView`. Ranges are UTF-16 (`NSRange`), so emoji and CJK text line up. `marker` spans cover the `*`, `_`, `[[`, `]]`, `[]`, `[x]` characters so the editor can dim them.

Edge filter: a note shows when `onEdge`, not completed, and not snoozed past `now`. A pinned note also needs its `appBundleId` or `siteHost` to equal the current `ContextKey`; hosts compare case-insensitively and ignore a leading `www.`. Order: context matches, then due soonest, then newest.

## Edge cases and limits

- Link titles match a note's first non-empty line, case-insensitively. Unknown titles create no link. A note never links to itself. If two notes share a title, both are linked.
- Links are rebuilt only when the linking note is saved. Renaming a note does not update links from other notes, and a note created later is not linked from earlier notes until they are saved again.
- `[[ ]]`, `[[]]`, an unclosed `[[`, and a link split across lines are ignored.
- `*bold*` and `_italic_` need a non-space character after the opening and before the closing mark, and stay on one line. Like Slack, a mark touching a letter or digit outside it is plain text, so `snake_case_name` and `2*3*4` are not styled. Formatting inside a `[[link]]` is not applied.
- Checkboxes count only at line start (optionally after `- `). `togglingCheckbox` leaves text unchanged for a line without a checkbox or a line number out of range.
- `[[` suggestions and link rebuilding read every note into memory (SQLite `LIKE` is ASCII-only). Fine for a personal library; revisit past roughly 10,000 notes.
- `contextGroups()` includes completed notes.
- `noteCounts()` counts completed notes and returns 0 for empty projects.
