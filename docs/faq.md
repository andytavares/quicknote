# FAQ

## Does Quicknote sync between Macs?

No. Quicknote has no sync, no account and no server. Your notes are one SQLite file and an `Attachments/` folder on this Mac. You can export everything as Markdown (Settings › Data) and move it yourself.

## Is it really free?

Yes. There are no payments, trial or account. The licence is not decided yet.

## Which Macs and macOS versions?

macOS 26 or later. Quicknote uses one speech engine (`SpeechAnalyzer`) and Apple's on-device language models, and carries no fallback for older systems ([decision 2](decisions/0002-macos-26-and-later.md)). If your Mac runs macOS 26 or later, Quicknote runs. The project has no separate Intel or Apple silicon rule, so macOS 26 support is what decides. Summaries also need a Mac where Apple Intelligence is available.

## Why do meeting summaries sometimes say "not available"?

The summary uses the system language model on your Mac. If Apple Intelligence is off or unsupported, the summary stays empty. The transcript and action items do not need it ([meetings](features/meetings.md)).

## Which languages work?

Voice notes, meeting transcripts and the text read from images are English only. The first use downloads Apple's English speech model. Search matches accents and word stems. The sorting rules read English words such as "tomorrow" ([sorting and repeats](features/sorting-and-repeats.md)).

## Why isn't it in the Mac App Store?

App and site notes need the Accessibility API, which Apple does not support in sandboxed apps, and the App Store requires the sandbox. Quicknote ships as a signed, notarized DMG and updates with Sparkle ([decision 8](decisions/0008-developer-id-distribution.md)).

## Why does Slack sharing mean pasting?

Slack for Mac has no share extension and Slack's links cannot upload a new file. "Slack" in the Share menu copies the image and opens Slack; you paste with `⌘V`. Dragging the PNG out of the editor also works. Uploading through Slack's API would need an account and a token ([decision 7](decisions/0007-slack-copy-and-open.md)).

## Why does Quicknote want full Calendar access?

Write-only access cannot read events back, so the Daily Brief could not show them and a note edit could not update its event ([decision 6](decisions/0006-calendar-full-access.md)). Quicknote writes an event only after you press **Add event**.

## What happens to calendar events when I delete a note?

Deleting a note that has an event asks whether to delete the event too. If you delete the event in Calendar, the note stays and loses its event link. Delete everything leaves events already in Calendar ([calendar and brief](features/calendar-and-brief.md)).

## Why did nothing pop up when I woke my Mac?

By design. Quicknote shows only what you opened, a reminder you set, or a note you pinned to the app in front ([decision 5](decisions/0005-nothing-pops-up-unasked.md)). The Daily Brief opens only from the menu.

## Does search look at my files or other apps?

No. Search covers only Quicknote's notes, meeting transcripts, and attachment names and image text.

## A reminder came while Quicknote was closed. Is that right?

The notification is delivered by macOS. The slide-out on the edge needs Quicknote to be running ([edge and context](features/edge-and-context.md)).

## Where is my data, and how do I remove it?

`~/Library/Application Support/Quicknote`. See [privacy](privacy.md).

## A feature stopped working.

Check Settings › Permissions. Each feature needs one or more permissions, and macOS sometimes needs a relaunch of Quicknote after you allow Screen Recording ([permissions](permissions.md)).
