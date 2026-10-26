import KeyboardShortcuts
import SwiftUI

/// The menu under the menu bar icon (screen S01).
struct MenuBarMenu: View {
    private let permissionCheck = PermissionCheck.shared
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        if !permissionCheck.missing.isEmpty {
            Button(PermissionCheck.summary(of: permissionCheck.missing), systemImage: "exclamationmark.triangle") {
                SettingsTab.show(.permissions, using: openSettings)
            }
            Divider()
        }
        Button("New note") { CaptureFeature.showPanel() }
            .globalKeyboardShortcut(.newNote)
        Button("Hold to talk") { VoiceFeature.startHoldToTalk() }
            .globalKeyboardShortcut(.holdToTalk)
        Button("Snap") { SnapFeature.start() }
            .globalKeyboardShortcut(.snap)
        Button("New card") { CardsFeature.newCard(fromNoteId: LibraryFeature.openNoteId) }
            .globalKeyboardShortcut(.newCard)
        Button("Search") { SearchFeature.showPanel() }
            .globalKeyboardShortcut(.search)
        Button("Save where I stopped") { CaptureFeature.showSaveContext() }
            .globalKeyboardShortcut(.saveContext)
        Divider()
        Button(MeetingsFeature.isRecording ? "Stop meeting recording" : "Start meeting recording") {
            MeetingsFeature.toggleRecording()
        }
        Button("Daily Brief") { BriefFeature.show() }
        Button("Open Library") { LibraryFeature.show() }
        Divider()
        Button("Hide edge tabs for 1 hour") { EdgeFeature.hideForOneHour() }
        Button("Settings…") { SettingsTab.show(using: openSettings) }
            .keyboardShortcut(",")
        Button("Check for updates…") { UpdatesFeature.checkForUpdates() }
        Button("Quit Quicknote") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
