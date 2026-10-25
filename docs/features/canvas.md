# Canvas and cards

One canvas model draws both Snaps (S20) and Cards (S21, S22). It lives in `QuicknoteKit` and has no UI; the app renders it.

## Document

`CanvasDocument` (`Canvas/CanvasDocument.swift:67`) holds a `background`, `elements`, an optional `caption` and `showsMadeWithMark` (default false).

- `.image(attachmentId:size:)` is a Snap: the captured image is an attachment on the note.
- `.card(style:size:)` is a Card: paper style and export size.
- `elements` is z-order. The last element is on top.

## Element kinds

`ElementKind` (`Canvas/CanvasDocument.swift:11`):

| Kind | Draws |
|---|---|
| `arrow`, `line` | A segment with (arrow) or without a head |
| `box`, `diamond`, `circle`, `triangle` | Outlined shape filling the frame (triangle apex is top centre) |
| `text(String)` | Text in the style's font and colour |
| `step(number:)` | Numbered badge; numbers are managed by the document |
| `highlight` | Translucent marker rectangle |
| `blur` | Blurs the image under the frame |
| `sticker(String)` | An emoji or a bundled sticker name |
| `photo(attachmentId:)` | An attachment image (Cards) |
| `washi(pattern:)` | Strip of washi tape in a pattern |
| `ink(points:)` | Freehand stroke; points are relative to the frame origin |
| `extraNote(text:colorHex:)` | A small coloured note pinned to a Card |

`CanvasElement` (`:37`) has `frame` (unrotated, canvas coordinates), `rotation` (radians, about the frame centre) and `style` (`colorHex`, `strokeWidth`, `fontName?`).

Arrows and lines run from the frame's (minX, minY) to (maxX, maxY). `flippedX` / `flippedY` mirror that diagonal on one axis. Flags were chosen over start/end points so move and resize stay plain rectangle maths.

## Move, resize, rotate, hit-testing

All geometry works in the element's local space: the canvas point is rotated by `-rotation` about the frame centre (`CanvasElement+Geometry.swift`).

```
canvas point --rotate by -rotation about centre--> local point
                                                     |
   hit-test: inside the shape? (line: <= 6pt from segment)
   resize:   move the dragged edges, keep the others (min 8x8)
                                                     |
   new local rect --centre mapped back by +rotation--> new frame
```

- Move adds an offset to the frame. Rotate sets `rotation`.
- Resize takes a `ResizeHandle` (8 handles) and the dragged point in canvas coordinates. Only the edges the handle owns change, so the opposite side stays fixed on screen even when rotated. The smallest side is 8pt. Ink points scale with the frame.
- `elementID(at:)` returns the topmost element containing the point: rectangle for text, stickers and the like, ellipse for `circle`, diamond and triangle by their outline, 6pt distance for `line` and `arrow`.
- `add` gives a new `step` the next number. `remove` and `renumberSteps` renumber steps 1...n in z-order.

## Undo

`CanvasHistory` (`Canvas/CanvasHistory.swift:2`) is a value type. Record the starting document, then the result of every edit. `undo()` and `redo()` return the document to show, or nil at the ends. Recording after an undo drops the redo branch. At most 100 states are kept; the oldest drops first.

## Card styles and sizes

| Style | Paper | | Size | Pixels |
|---|---|---|---|---|
| Sticky | `#FBE38E` | | Square | 1080 x 1080 |
| Postcard | `#FFFDF8` | | Story | 1080 x 1920 |
| Polaroid | `#FFFDF8` | | Wallpaper | the display's pixel size, stored in the card |
| Lined | `#FFFFFF` | | | |
| Minimal | `#FFFFFF` | | | |
| Kraft | `#C9A57A` | | | |

All styles use ink `#2B2618`. See `Cards/CardStyle.swift:4` and `Cards/CardSize.swift:4`.

## Storage

`Note.canvas` (`Canvas/Note+Canvas.swift:5`) encodes the document as JSON into `Note.canvasJSON`. Reading JSON that does not decode returns nil; it never crashes. Setting nil clears the column. There is no schema change.
