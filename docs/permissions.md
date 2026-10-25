# Permissions

Quicknote asks for each permission the first time a feature needs it, never at launch (S02, S03). Before the system prompt it shows its own explainer card. If a permission was refused, the same card opens the right System Settings pane. Live status is in Settings › Permissions (S26).

| Permission | Why | Asked when | Still works without it | Change it later |
|---|---|---|---|---|
| Microphone | Hold to talk and the "me" side of meetings | First hold to talk or meeting | Typed notes, Snap, cards, search | Privacy & Security › Microphone |
| Speech recognition | Turn voice and meetings into text on this Mac | First transcript | Audio still records; no text | Privacy & Security › Speech Recognition |
| Mac audio for meetings | Record the other people on a call | First meeting | Meetings record your microphone only | Privacy & Security › Screen & System Audio Recording |
| Screen Recording | Snap reads the screen while you drag | First Snap | Everything except Snap | Privacy & Security › Screen & System Audio Recording |
| Accessibility | Read the front app or site name for app and site notes | First app or site note | Notes work; they just don't slide out by themselves | Privacy & Security › Accessibility |
| Calendar (full access) | Add confirmed events, read today for the Daily Brief | First event or Daily Brief | Notes and reminders; no events, brief without events | Privacy & Security › Calendars |
| Notifications | Bring a reminder back at its time | First reminder | Reminders appear in the edge and Daily Brief only | Notifications › Quicknote |

## Status you will see

- Mac audio has no system status API. It reads "Checked on first meeting" until a meeting has recorded audio; the meeting recorder reports the outcome with `Permissions.recordSystemAudioResult(allowed:)`.
- Screen Recording and Accessibility cannot tell "never asked" from "refused". Quicknote remembers that it asked (`permissionRequested.<name>`), so before the first ask the status is "not asked" and afterwards "off".
- macOS often needs a relaunch of the app before a newly allowed Screen Recording takes effect.

## Deep links (verified)

Checked on macOS 27 against `SecurityPrivacyExtension.appex` (`Contents/Resources/TCCServiceList.plist` and the binary's strings) and `NotificationsSettings.appex`: `Privacy_Microphone`, `Privacy_SpeechRecognition`, `Privacy_AudioCapture`, `Privacy_ScreenCapture`, `Privacy_Accessibility`, `Privacy_Calendars` under `x-apple.systempreferences:com.apple.preference.security?`, and `x-apple.systempreferences:com.apple.Notifications-Settings.extension`. Not opened in a live System Settings window; see the manual checklist.

## For features

```swift
guard await Permissions.ensure(.screenRecording) else { return }
```

`ensure` returns true only when the feature may proceed. It returns false after "Not now", after a refusal, or when the pane was opened.
