# Sharing

The **Share ▾** menu (S23) in the Snap editor, and in the Card editor. Code: `Export/ShareMenu.swift`.

| Item | What it does |
|---|---|
| Messages, Mail, AirDrop | The system sharing service of that name (`NSSharingService`) gets the image and the caption |
| Slack | Copies the image and caption, opens Slack, shows "Copied — paste in Slack with ⌘V" |
| Copy image | The image (and caption) on the clipboard |
| Save as PNG… | A save panel, then the full-resolution PNG |
| Export as Markdown… | Pick a folder; the note is written with its attachments (`MarkdownExporter`, see [search and export](search-and-export.md)) |

If Messages, Mail or AirDrop cannot take the items on this Mac, the menu says "<name> isn't available on this Mac."

## Why Slack works this way

Slack for Mac has no share extension, so it is not in the system share menu, and its deep links cannot upload a new file. So "Slack" copies the image and caption (one pasteboard item with `public.png` and a string) and opens `slack://open`; you paste with `⌘V`. If no app handles the `slack` scheme the menu says "Slack isn't installed on this Mac. The image is copied; paste it where you like." Dragging the PNG out of the editor also works. See [decision 0007](../decisions/0007-slack-copy-and-open.md).

## For other features (Cards)

```swift
ShareMenu(payload: { await save() })   // Share ▾ menu; payload runs on every action, nil cancels
SharePayload(image: CGImage, caption: String, noteId: Int64)   // the note must already be saved
ShareActions.copyImage(of:to:), .shareToSlack(_:pasteboard:opener:), .send(_:via:), .savePNG(_:), .exportMarkdown(_:)
```

`SlackOpener` (`ShareMenu.swift:14`) finds and opens Slack; tests replace it.

## Limits

- Messages with an image only works if the Messages service accepts it on this Mac.
- Whether Slack pastes the image or the caption when both are on the clipboard is Slack's choice: check below.
- "Copy image" has no `⌘C` shortcut, so copying text in the caption field is not hijacked.

## Manual test checklist

- [ ] Messages, Mail and AirDrop open with the image attached.
- [ ] Slack installed: it opens, `⌘V` in a channel pastes the image; the notice appears.
- [ ] Slack not installed: the notice says so and the image is still on the clipboard.
- [ ] Save as PNG… writes a file that opens at the editor's size.
- [ ] Export as Markdown… writes the `.md` and an attachments folder with the PNG.
