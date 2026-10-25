# Cards

Turn a note, or nothing, into a picture to share: the Card editor (S21) and the six styles and three sizes (S22). Cards use the shared canvas model, see [canvas.md](canvas.md).

## Making a card

- Menu bar "New card" or `⌃⌥C`: a card from the note open in the Library (when its window is on screen), otherwise a blank sticky card.
- "Make a card" in the note editor: a sticky card with the note's text (first 240 characters) as a text element. The card is saved as a new note; the original note is not changed.
- Gallery: open a card to edit it again (`CardsFeature.edit(noteId:)`).

## Styles

| Style | What is drawn |
|---|---|
| Sticky | Yellow paper, a slight shadow band along the top |
| Postcard | Centre divider, a stamp box and address lines on the right half |
| Polaroid | Pale picture window inside a frame that is thicker at the bottom |
| Lined | Ruled lines and a red margin |
| Minimal | Plain paper |
| Kraft | Brown paper with fibres from a fixed random seed, so a card always renders the same |

Paper colours come from `CardStyle`. Painting is Core Graphics in `CardBackgroundPainter`, plugged into `CanvasResources.paintBackground`.

## Decorating

Select, move, resize and rotate anything with the mouse (handles as in Snap). `⌫` or "Delete" removes the selection. Undo `⌘Z`, redo `⇧⌘Z`.

- **Emoji**: a popover grid of 16 emoji. **Stickers**: six built-in stickers (🎂 ✨ 🌻 ★ ♥ ✈️).
- **Photo…**: pick an image; it is copied into the note as an `.image` attachment and placed as a photo element.
- **Text** and **Extra note**: added with placeholder text; edit it in the field under the card.
- **Washi tape**: four looks (pink, mint stripes, blue, gold stripes).
- **Sign**: turns drawing on; drag on the card to draw a freehand ink element. Press Sign again to go back to selecting. A click without a stroke adds nothing.
- **Add “made with Quicknote”**: off by default; draws a small grey mark at the bottom right.

## Sizes and saving

| Size | Pixels |
|---|---|
| Square | 1080 x 1080 |
| Story | 1080 x 1920 |
| Wallpaper | the main display's pixel size when chosen |

A card is saved to its note as canvas JSON plus `preview.png` (a `.snap` attachment, replaced on each save). It saves on Save PNG and Share, and when the window closes after any edit. A card you never touched is not saved.

## Export and sharing

Save PNG renders the card at its size with `CanvasRenderer` and writes a normal PNG that anyone can open or print. **Share ▾** is the shared [sharing](sharing.md) menu.

## Where the code is

- `Cards/CardsFeature.swift:10` `newCard(fromNoteId:)`, `:17` `edit(noteId:)`, then `CardEditorWindow.show`.
- `Cards/CardEditorView.swift:6` window layout; `Cards/CardDecoratePanel.swift` Decorate column.
- `Cards/CardEditorModel.swift:233` pointer events; `:136` size; `:181` photo; `:242` ink; `:221` save.
- `Cards/CardSaver.swift:52` note, canvas JSON and preview.
- `Cards/CardBackgroundPainter.swift:12` the six papers.

## Limits

- Wallpaper keeps the size it was made at; it does not follow a display change.
- Long note text overflows its text element's frame instead of shrinking.
- Photos are not removed from the note when their element is deleted.
- Only plain and striped washi tape exist.
- Emoji and stickers are text glyphs, so their look depends on the system emoji font.

## Manual test checklist

- [ ] With a note open in the Library, `⌃⌥C` and "New card" carry its text; with the Library closed they open a blank sticky card. "Make a card" in a note carries its text.
- [ ] Each of the six styles looks right at all three sizes.
- [ ] Add an emoji, a sticker, a photo, tape, text and an extra note; move, resize and rotate each; `⌫` deletes.
- [ ] Sign draws; Sign again returns to selecting.
- [ ] The "made with Quicknote" toggle shows and hides the mark, and is remembered after reopening.
- [ ] Save PNG opens in Preview at the chosen size; Share ▾ items work.
- [ ] Close and reopen from the Gallery: everything is still there.
- [ ] Every control is reachable with Tab and has a VoiceOver label.
