import AppKit
import SwiftUI

/// Library window and note editor (S10–S13, S16, S24).
enum LibraryFeature {
    private static var window: NSWindow?
    private static let model = LibraryModel(
        database: AppEnvironment.current.database, paths: AppEnvironment.current.paths)

    static func show() {
        let window = window ?? makeWindow()
        Self.window = window
        DockIcon.show()
        window.makeKeyAndOrderFront(nil)
    }

    /// The note open in the Library while its window is on screen, so ⌃⌥C can turn it into a card.
    static var openNoteId: Int64? {
        window?.isVisible == true ? model.openNoteId : nil
    }

    /// Opens the Library with one note selected.
    static func open(noteId: Int64) {
        model.open(noteId: noteId)
        show()
    }

    private static func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1_100, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered,
            defer: false)
        window.title = "Quicknote"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: LibraryView(model: model))
        window.center()
        return window
    }
}
