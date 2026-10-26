# Quicknote documentation

## Using Quicknote

- [User guide](user-guide.md): one section per job, from first launch to deleting your data
- [Shortcuts](shortcuts.md): every global and in-app key, and how to change them
- [FAQ](faq.md)
- [Privacy](privacy.md): what is stored, what never leaves the Mac, the few network calls
- [Permissions](permissions.md): what each permission is for and what works without it

## Features

One page per feature, with how it works, limits and a manual test checklist.

| Page | Covers |
|---|---|
| [Capture](features/capture.md) | Quick capture panel, Save where you stopped |
| [Voice](features/voice.md) | Hold to talk, on-device speech |
| [Sorting and repeats](features/sorting-and-repeats.md) | Type, due date and repeat from your words |
| [Edge tabs and context](features/edge-and-context.md) | Edge tabs, app and site notes, reminders |
| [Reminders and the Daily Brief](features/reminders-and-brief.md) | Alerts, snooze, brief contents, read-aloud |
| [Calendar and the Daily Brief](features/calendar-and-brief.md) | Add to Calendar, two-way sync, the Brief window |
| [Library](features/library.md) | Sidebar, lists, task views, gallery |
| [Editor](features/editor.md) | Toolbar, links, style, calendar changes |
| [Notes, links and formatting](features/notes-links-formatting.md) | Types, projects, `[[links]]`, formatting rules |
| [Search, export and delete](features/search-and-export.md) | Search panel, Markdown export, delete everything |
| [Meetings](features/meetings.md) | Recording, transcript, summary, action items |
| [Snap](features/snap.md) | Screen selection and markup editor |
| [Canvas and cards](features/canvas.md) | Shared canvas model for Snap and Cards |
| [Cards](features/cards.md) | Card editor |
| [Sharing](features/sharing.md) | Share menu, Slack |
| [Settings, permissions and welcome](features/settings-and-permissions.md) | Settings tabs, permission cards, welcome |

## For developers

- [Development](development.md): setup, checks, where code goes
- [Architecture](architecture.md): launch, folders, data
- [Releasing](release.md): signing, notarizing, Sparkle
- [Original design and screen renderings](design.html), S01 to S26. Its open questions are answered in the decisions below.

## Decisions

1. [Native Swift app](decisions/0001-native-swift.md)
2. [macOS 26 and later](decisions/0002-macos-26-and-later.md)
3. [SQLite through GRDB, search with FTS5](decisions/0003-grdb-fts5.md)
4. [Logic lives in the QuicknoteKit package](decisions/0004-logic-package.md)
5. [Nothing pops up unless you asked for it](decisions/0005-nothing-pops-up-unasked.md)
6. [Calendar: full access, events kept in sync](decisions/0006-calendar-full-access.md)
7. [Share to Slack copies the image and opens Slack](decisions/0007-slack-copy-and-open.md)
8. [Distributed outside the Mac App Store](decisions/0008-developer-id-distribution.md)
