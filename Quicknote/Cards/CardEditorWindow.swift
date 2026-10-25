import AppKit
import QuicknoteKit
import SwiftUI

/// The Card editor window (S21). Each window owns one `CardEditorModel`.
enum CardEditorWindow {
    private static var open: [(window: NSWindow, noteId: Int64?)] = []

    /// A saved card already open is brought forward, so two windows never overwrite each other's edits.
    static func show(document: CanvasDocument, noteId: Int64?) {
        if let noteId, let existing = open.first(where: { $0.noteId == noteId }) {
            NSApp.activate()
            return existing.window.makeKeyAndOrderFront(nil)
        }
        let model = CardEditorModel(document: document, noteId: noteId, saver: .live)
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 1000, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = noteId == nil ? "New card" : "Card"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: CardEditorView(model: model))
        window.center()
        open.append((window, noteId))
        // A task rather than a block observer: it ends at close, so nothing keeps the window and its model alive.
        Task {
            for await _ in NotificationCenter.default.notifications(
                named: NSWindow.willCloseNotification, object: window)
            {
                open.removeAll { $0.window === window }
                return
            }
        }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}
