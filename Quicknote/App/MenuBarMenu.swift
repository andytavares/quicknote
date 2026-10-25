import KeyboardShortcuts
import SwiftUI

/// The menu under the menu bar icon (screen S01).
struct MenuBarMenu: View {
    var body: some View {
        Button("New note") { CaptureFeature.showPanel() }
            .globalKeyboardShortcut(.newNote)
        Button("Hold to talk") { VoiceFeature.startHoldToTalk() }
            .globalKeyboardShortcut(.holdToTalk)
        Button("Snap") { SnapFeature.start() }
            .globalKeyboardShortcut(.snap)
        Button("New card") { CardsFeature.newCard(fromNoteId: nil) }
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
        SettingsLink { Text("Settings…") }
            .keyboardShortcut(",")
        Button("Check for updates…") { UpdatesFeature.checkForUpdates() }
        Button("Quit Quicknote") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
