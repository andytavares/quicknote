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
