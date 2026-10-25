# Search, export and delete everything

Screens S15 (search) and S26 (data settings) in [design.html](../design.html).

## What search covers

Only what Quicknote itself stores. Nothing outside the app is indexed.

| Group | Matches in | Hit shows |
|---|---|---|
| Notes | note body | note, snippet |
| Transcripts | meeting transcript lines | meeting title, start time (ms), snippet |
| Files | attachment file name and text read from images | attachment, note id, snippet |

## Query behavior

- Every word must match, and each word matches as a prefix: `pric page` finds "pricing page".
- Stemming and accent folding come from the index tokenizer (`porter` over `unicode61`).
- Empty, blank or punctuation-only text (`"`, `*`, `(`, `AND`) returns empty results, never an error. User text is never passed to FTS5 as raw syntax.
- Ranked by bm25 within each group. In Notes, open notes come before completed ones.
- `limitPerGroup` caps each group separately.
- Snippets wrap matched words in `SearchIndex.markStart` and `SearchIndex.markEnd` (`«` and `»`) and cut with `…`.

## Cleaning up after deletes

Deleting a note removes its database rows at once. Its folder `Attachments/<noteId>/`, and `Attachments/meetings/<meetingId>/` for a deleted meeting, is removed at the next launch by `AttachmentStore.removeOrphanedFiles()` (`QuicknoteKit/Sources/QuicknoteKit/Attachments/AttachmentStore+Orphans.swift`). Only numbered folders whose note or meeting no longer exists are touched.

## Export on disk

`MarkdownExporter.export` writes `<slug>.md` and, when the note has attachments, a `<slug>/` folder beside it. The slug is the lowercased title with every run of other characters turned into `-` (60 characters at most, `note` if nothing is left). If `<slug>.md` or `<slug>/` exists, `-2`, `-3` and so on are added. Front matter lines with no value are left out. Text values are JSON-quoted, which is valid YAML. `recurrenceJSON` is the stored JSON string as is. `[[links]]` stay in the body.

```
out/
  lisbon-trip.md
  lisbon-trip/
    map.png
    pass.pdf
```

`lisbon-trip.md`:

```markdown
---
kind: task
created: 2023-11-14T22:13:20Z
updated: 2023-11-14T22:13:20Z
app: "Safari"
project: 7
---

Lisbon trip
See [[Flights]] for times

![map.png](lisbon-trip/map.png)
[pass.pdf](lisbon-trip/pass.pdf)
```

Images use `![name](path)`, other files `[name](path)`. Two attachments with the same name get the attachment id as a prefix in the folder. `exportAll` writes every note into one folder and returns the count.

## Delete everything

`DataEraser.eraseEverything` runs in one database transaction.

- Removes: every row in every table (notes, projects, attachments, links, meetings, transcript lines, bookmarks) and with them the search indexes, then every file under `Attachments/`, including meeting audio.
- Keeps: the database file with its schema, the empty `Attachments/` folder, and anything outside Quicknote's folder (exports you wrote elsewhere, app preferences).
- The database accepts new notes straight afterward.

## Code entry points

- Attach and remove files: `QuicknoteKit/Sources/QuicknoteKit/Attachments/AttachmentStore.swift:14`
- Search: `QuicknoteKit/Sources/QuicknoteKit/Search/SearchIndex.swift:42`
- Export one note: `QuicknoteKit/Sources/QuicknoteKit/Export/MarkdownExporter.swift:12`
- Export all: `QuicknoteKit/Sources/QuicknoteKit/Export/MarkdownExporter.swift:29`
- Delete everything: `QuicknoteKit/Sources/QuicknoteKit/Export/DataEraser.swift:14`

## Search panel

Screen S15. Searches only Quicknote's own notes, meeting transcripts, and attachment names and image text (the table in "What search covers"). Nothing outside Quicknote is read or indexed, and nothing leaves the Mac.

### Use

1. Press ⌃⌥F in any app. A floating panel opens centred horizontally on the screen the mouse is on, with the field focused. Pressing ⌃⌥F while it is open refocuses the field and selects its text.
2. Type. Results update about 120 ms after you stop typing; the search runs off the main thread, and a newer query cancels an older one. Matches are bold and tinted in each snippet.
3. Results are grouped as Notes, Meeting transcripts, and Files and Snaps. Transcript rows show `mm:ss` and the meeting title.
4. ↑ and ↓ move through all results across groups and stop at the first and last row (no wrap). ↵ or a click opens the row. ⌘↵ shows the Library.
5. Esc, or clicking away, closes the panel.

| Row | Opens with |
|---|---|
| Note | `LibraryFeature.open(noteId:)` |
| Transcript | `MeetingsFeature.open(meetingId:atMs:)` at the matching line |
| File or Snap | `LibraryFeature.open(noteId:)` of the note it is attached to |
| ⌘↵ | `LibraryFeature.show()` |

With no query the panel says "Type to search notes, meetings and files"; with no hits, "No matches". The result count is announced to VoiceOver and every row has an accessibility label (group, snippet, detail, time).

### Limits

- 8 results per group (`limitPerGroup`), so a very common word shows only the best 8 of each.
- Whole words only as prefixes; no phrase or operator syntax (see Query behavior).
- Search errors show as no results.
- The last query stays in the field when the panel is opened again; select-all lets you type over it.

### Entry points

- Open the panel: `Quicknote/Search/SearchFeature.swift:11` (`showPanel`), called from `Shortcuts.swift`
- Panel window: `Quicknote/App/KeyPanel.swift` (shared with capture and the meeting start sheet)
- Query, debounce, selection: `Quicknote/Search/SearchModel.swift:7`
- Rows, groups, open actions: `Quicknote/Search/SearchRow.swift:16`
- Highlight rendering: `Quicknote/Search/SearchSnippet.swift:7`
- View: `Quicknote/Search/SearchView.swift:5`
- Tests: `QuicknoteTests/SearchTests.swift`

### Manual test checklist

- [ ] ⌃⌥F over another app opens the panel on the mouse's screen and typing works at once.
- [ ] Esc closes it; clicking another window closes it.
- [ ] A word in a note, a transcript and a file name shows all three groups with highlights.
- [ ] ↑/↓ cross group boundaries; ↵ opens a note, a transcript at the right second, a file's note.
- [ ] ⌘↵ shows the Library.
- [ ] ⌃⌥F while open selects the text in the field.
- [ ] Empty field shows the hint; gibberish shows "No matches".
- [ ] VoiceOver announces the count and reads each row.
- [ ] Works with Wi-Fi off.
