import AppKit
import SwiftUI

/// Floating panel that takes keys without activating Quicknote, over any app including full-screen ones.
/// Used by search, capture, Save where you stopped and the meeting start sheet.
final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 100),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.contentView = contentView
    }

    convenience init<Content: View>(rootView: Content) {
        self.init(contentView: NSHostingView(rootView: rootView))
    }

    override func cancelOperation(_ sender: Any?) { close() }

    /// Sizes to the content, centres on the mouse's screen and takes keys.
    func showCentered() {
        if let size = contentView?.fittingSize { setContentSize(size) }
        centerOnMouseScreen()
        makeKeyAndOrderFront(nil)
    }

    /// Centres horizontally and in the upper third of the screen the mouse is on.
    func centerOnMouseScreen() {
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? .main
        guard let frame = screen?.visibleFrame else { return }
        setFrameOrigin(
            NSPoint(x: frame.midX - self.frame.width / 2, y: frame.maxY - frame.height / 3 - self.frame.height))
    }
}
