# Settings, permissions and welcome

Screens S02 (welcome), S03 (permission explainer), S25 and S26 (settings) in [design.html](../design.html). Per-permission detail is in [../permissions.md](../permissions.md).

There is no "Open Daily Brief at first unlock" setting: [decision 5](../decisions/0005-nothing-pops-up-unasked.md).

## Settings window

Menu › Settings… (⌘,). Four tabs; the last one used is remembered (`settingsTab`).

### General

| Setting | Changes | Stored |
|---|---|---|
| Open at login | Adds or removes Quicknote in Login Items (`SMAppService.mainApp`); the toggle re-reads the system state | system |
| Show edge tabs on all displays | Edge tabs on every display or only the main one; calls `EdgeFeature.refresh()` | `showsEdgeOnAllDisplays` |
| Pop up app and site notes | Notes pinned to an app or site slide out when it is in front | `popsUpContextNotes` |
| Default note colour | Colour of new notes: Yellow, Pink, Green, Blue, Lilac, Orange | `defaultNoteColor` (hex) |
| Default font | The six editor fonts: Handwritten, System, Rounded, Serif, Marker, Mono | `defaultFont` (ids from `EditorFont.choices`, `Quicknote/Editor/EditorFont.swift`) |
| Voice | English, on this Mac. Fixed, not a control | none |
| Updates: check automatically | Sparkle's automatic checks | `SUEnableAutomaticChecks`, the key Sparkle reads |

### Shortcuts

One recorder per entry in `Shortcuts.all`; it warns when a key is taken. Restore defaults resets all of them.

### Permissions

Live status per permission, refreshed when the window opens and whenever Quicknote becomes active again (so a change made in System Settings shows without reopening). Button per row: Allow (system prompt) when never asked, Open Settings when refused.

### Data

- Stored on this Mac: note count, meeting count, size on disk of the Quicknote folder (`DataSummary`).
- Show in Finder opens the folder.
- Export everything: choose a folder; `MarkdownExporter.exportAll` writes one `.md` per note plus attachment folders.
- Delete everything: press the button, type `DELETE` (exact, upper case; nothing else enables it), then `DataEraser.eraseEverything`, remove all pending notifications, `EdgeFeature.refresh()`. Calendar events already created stay. Cannot be undone.

## Welcome

Shown once, at first launch (`welcomeShown`). Open at login toggle, Change shortcuts (opens Settings on Shortcuts), Start. No permission prompts.

## Code entry points

- Permission API: `Quicknote/App/Permissions.swift:105` (`status(of:)`), `:134` (`ensure`)
- Decision table: `Quicknote/App/Permissions.swift:22` (`PermissionStep.next`)
- Explainer card: `Quicknote/Settings/PermissionExplainerPanel.swift:6`
- Settings window and tabs: `Quicknote/Settings/SettingsView.swift:22`; open on a tab: `SettingsTab.show`
- Preferences: `Quicknote/Settings/AppSettings.swift`
- Data pane and delete: `Quicknote/Settings/DataPane.swift`, `DataSummary.swift`
- Welcome: `Quicknote/Welcome/WelcomeFeature.swift:9`

## Manual test checklist

- [ ] Fresh defaults: Welcome appears once; relaunch does not show it. No system prompt appears.
- [ ] Welcome › Change shortcuts opens Settings on Shortcuts.
- [ ] Grant: first hold to talk shows the explainer, Continue shows the system prompt, Allow proceeds. Repeat for each permission in permissions.md.
- [ ] Deny: refuse the prompt; trigger the feature again; the card shows the steps and Open System Settings lands on the right pane (check all seven).
- [ ] Revoke while running: turn Microphone off in System Settings with Settings › Permissions open; return to Quicknote; the row changes to Open Settings.
- [ ] Open at login: toggle on, see Quicknote in System Settings › Login Items; toggle off.
- [ ] Rebind a shortcut, Restore defaults.
- [ ] Data: counts match the Library; Export writes files; Delete everything stays disabled until `DELETE` exactly, then empties notes and removes reminders.
- [ ] Everything reachable with Tab and Space; VoiceOver reads each control.
