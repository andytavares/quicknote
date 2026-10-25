import AppKit
import QuicknoteKit
import SwiftUI

/// The Card editor window (S21). Each window owns one `CardEditorModel`.
enum CardEditorWindow {
    private static var open: [NSWindow] = []

    static func show(document: CanvasDocument, noteId: Int64?) {
        let model = CardEditorModel(document: document, noteId: noteId, saver: .live)
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 1000, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = noteId == nil ? "New card" : "Card"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: CardEditorView(model: model))
        window.center()
        open.append(window)
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { _ in
            MainActor.assumeIsolated { open.removeAll { $0 === window } }
        }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}
