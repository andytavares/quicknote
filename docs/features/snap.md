# Snap

Press `⌃⌥4`, drag a box around anything on screen, mark it up, send it. Screens S19 (selection) and S20 (editor).

## Taking a Snap

1. `⌃⌥4` (Settings › Shortcuts). The first time, Screen Recording is asked through `Permissions.ensure(.screenRecording)` ([permissions](../permissions.md)).
2. Every display dims. Drag a rectangle; a label shows its size in pixels. `Esc` cancels. A drag under 4 points is ignored.
3. On release the rect is captured with ScreenCaptureKit (`SCScreenshotManager`), at the display's backing scale, without Quicknote's own overlay. An action bar appears by the selection:

| Button | Does |
|---|---|
| Mark up | Opens the editor with the image |
| Save to edge | Saves the Snap at once as a note on the edge |
| Copy | Puts the PNG on the clipboard |

Selection works across displays and scale factors: `SnapCaptureRequest.make` turns the global AppKit rect into the display-local top-left rect ScreenCaptureKit wants, and the output size in that display's pixels (`Snap/SnapCapture.swift:19`).

## Editor tools

Pick a tool in the row or press its key while the canvas has focus (keys do not fire while you type a caption).

| Tool | Key | Drag makes |
|---|---|---|
| Select | `V` | Moves, resizes (8 handles), rotates (round handle above the top edge) |
| Arrow, Line | `A`, `L` | A segment from where you pressed to where you let go |
| Box, Diamond, Circle, Triangle | `B`, `D`, `C`, `G` | An outlined shape filling the dragged rectangle |
| Text | `T` | Click, type, `Return` to finish. Empty text is discarded |
| Step | `S` | Click: a numbered badge. Numbers follow z-order and close gaps when you delete one |
| Highlight | `H` | A translucent yellow marker (`#F2C14E`), whatever colour is picked |
| Blur | `U` | Blurs the pixels under the box |

A click without a drag leaves nothing for shapes. Colours (red, yellow, blue) and stroke width (3, 6, 10 px) apply to the selection and to the next shapes. `⌫` deletes the selection, arrow keys nudge it (1 px, `⇧` 10), `Return` edits selected text. `⌘Z` / `⇧⌘Z` undo and redo (`CanvasHistory`, 100 steps).

## Caption

Type in the caption field or hold `⌃⌥K` and speak: while the editor is the key window `VoiceFeature.captionTarget` is set, so the words are appended to the caption and no note is made. It is cleared when the window loses focus or closes (`Snap/SnapEditor.swift`, `SnapEditorWindowDelegate`).

## Buttons

- **Copy** and **Save PNG**: the marked-up image at full resolution.
- **Share ▾**: see [sharing](sharing.md).
- **Drag PNG** (toolbar): drag it into Slack, Mail or Finder; the file is `Snap.png`.
- **Save to edge**: saves the note and closes the editor.

Copy, Save PNG, Share and Save to edge all save the note first, so the image you send is the image in Library.

## What is saved, and where

| Thing | Where |
|---|---|
| Note | kind `note`, `onEdge` true, body is the caption or "Snap · 11:20" |
| Original screenshot | attachment kind `.image`, `snap.png` |
| Markup | `Note.canvasJSON`, background `.image(attachmentId:size:)` pointing at the original |
| Latest render | attachment kind `.snap`, `preview.png`, replaced on every save (never two) |
| Text in the image | OCR by `ImageTextReader` into the original attachment's `extractedText`, so search finds it |

Files live under `~/Library/Application Support/Quicknote/Attachments/<noteId>/`. Re-saving keeps the original and its OCR text. `SnapFeature.edit(noteId:)` reopens a Snap from the canvas JSON and the original.

## Code

- `Snap/SnapFeature.swift:10` `start()`, `:24` `edit(noteId:)`.
- `Snap/SnapOverlay.swift:9` overlay windows and action bar; `Snap/SnapCapture.swift:42` capture.
- `Snap/SnapEditor.swift:11` window; `Snap/SnapEditorModel.swift:7` tools, selection, undo; `Snap/SnapTool.swift:49` what each tool makes.
- `Snap/SnapSaver.swift:30` save; `:49` preview replacement.
- Shared canvas: `Canvas/CanvasView.swift`, `Canvas/CanvasRenderer.swift`, `Canvas/ElementHandles.swift`, `Canvas/ElementDrag.swift` (select, move, resize and rotate; also used by Cards) ([canvas](canvas.md)).
- Tests: `QuicknoteTests/SnapTests.swift`, `SnapSaverTests.swift`, `CanvasRendererTests.swift`.

## Limits

- Canvas units are image pixels, so strokes look thin on very large captures; use a wider stroke.
- Dragging an arrow's handle past its start does not flip it.
- Undo shortcuts belong to the toolbar, so `⌘Z` in the caption field undoes the markup, not the text.
- Ink, stickers, photos, washi and extra notes are drawn by the renderer (Cards) but the Snap editor has no tool for them.
- Each selection is one display; a drag cannot span two.

## Manual test checklist

Needs a Mac with Screen Recording available. Not run by the build.

- [ ] `⌃⌥4` first time: explainer, system prompt, then the overlay.
- [ ] Drag on the main and a second display (also one at a different scale): the size label matches the saved image's pixels.
- [ ] `Esc` closes the overlay everywhere; nothing saved.
- [ ] The saved image has no dim overlay or action bar in it.
- [ ] Mark up: every tool draws; resize, rotate, move work on a rotated shape; blur hides text.
- [ ] Undo/redo, `⌫`, arrow nudges.
- [ ] Hold `⌃⌥K`, speak: the caption fills in, no note appears.
- [ ] Drag PNG into Slack and Finder.
- [ ] Save to edge: tab appears; Library shows the Snap; search finds a word that was in the screenshot.
- [ ] Reopen from Library, change something, save: one `preview.png` in the attachments folder.
- [ ] VoiceOver reads the tool, colour and button labels.
