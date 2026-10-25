import AppKit
import SwiftUI

/// Daily Brief (S14). Opens only from the menu (decision 0005).
enum BriefFeature {
    private static var window: NSWindow?

    static func show() {
        Task {
            _ = await CalendarBridge.shared.ensureAccess()
            let window = window ?? makeWindow()
            Self.window = window
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
        }
    }

    private static func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 560),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "Daily Brief"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: BriefView(model: BriefModel()))
        window.center()
        return window
    }
}
