# Privacy

Quicknote keeps everything on your Mac. It has no account, no cloud and no analytics. The app has no code that sends your notes anywhere.

## What is stored, and where

All of it is under `~/Library/Application Support/Quicknote/` (`AppPaths.live`, `QuicknoteKit/Sources/QuicknoteKit/Store/AppPaths.swift:12`).

| What | Where |
|---|---|
| Notes, projects, links, meetings, transcript lines, bookmarks, search indexes | `quicknote.sqlite` |
| Files you attach, Snap screenshots and their rendered previews | `Attachments/<noteId>/` |
| Meeting audio (`meeting.m4a`) | `Attachments/meetings/<meetingId>/` |

Text read from images (Vision, on this Mac) and meeting summaries are stored in the database.

Preferences (default colour, default font, edge options, shortcuts, "welcome shown", which permissions were asked) are stored in the app's macOS preferences, not in this folder. Notes, voice and screenshots are not in them.

## What never leaves your Mac

- Notes, attachments, Snaps and cards.
- Your voice. Speech is recognised on-device with `SpeechAnalyzer` ([voice](features/voice.md)). Only text is kept for voice notes.
- Meeting audio, transcripts and summaries. Summaries use the on-device system language model ([meetings](features/meetings.md)).
- Search. It covers only Quicknote's own data and runs locally ([search](features/search-and-export.md)).
- Calendar events you did not confirm. Quicknote writes an event only after you press **Add event**.

Quicknote has no analytics, crash reporting or telemetry code. A search of the source for `URLSession` finds nothing.

## Network use that does exist

| What | When | Who sees it |
|---|---|---|
| Speech model download | The first time you use voice or a meeting. macOS downloads the English model (`AssetInventory`, `Quicknote/Voice/LiveTranscriber.swift:135`) | Apple |
| Update check | Automatically, or from the menu "Check for updates…". Sparkle reads `https://github.com/andytavares/quicknote/releases/latest/download/appcast.xml` (`SUFeedURL`) and downloads a new DMG if one exists | GitHub |
| Share to Messages, Mail, AirDrop | Only when you pick one in Share | The service you chose |
| Slack | "Slack" copies the image to the clipboard and opens `slack://open`. Quicknote sends nothing to Slack ([decision 7](decisions/0007-slack-copy-and-open.md)) | Nobody until you paste |

Builds without a real update key (every build from source) never check for updates. Pasted links are never fetched: a bookmark's title is the link's host.

## Permissions

Quicknote asks for each permission the first time a feature needs it, never at launch. Without a permission, only the feature that needs it stops. The table of what each one is for is in [permissions.md](permissions.md).

Quicknote is not sandboxed, because app and site notes use the Accessibility API ([decision 8](decisions/0008-developer-id-distribution.md)). It is signed with the hardened runtime and asks only for the entitlements for microphone, Apple Events and calendars (`Quicknote/Resources/Quicknote.entitlements`).

## Export and delete everything

Settings › Data (screen S26):

- **Show in Finder** opens the folder above.
- **Export everything** writes one Markdown file per note, plus a folder of attachments beside each note that has them (`MarkdownExporter.exportAll`).
- **Delete everything** needs you to type `DELETE`. It empties every table and search index, deletes every file under `Attachments/` (including meeting audio) and removes pending notifications. It cannot be undone.

Delete everything does not remove calendar events Quicknote already created; delete those in Calendar. It also leaves exports you wrote elsewhere and the app's preferences. To remove the preferences and any trace of the app, quit Quicknote and delete `~/Library/Application Support/Quicknote` and the app.

Details: [search-and-export.md](features/search-and-export.md), [settings-and-permissions.md](features/settings-and-permissions.md).
