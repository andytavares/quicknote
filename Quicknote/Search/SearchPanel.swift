import AppKit
import QuicknoteKit
import SwiftUI

/// Floating panel that can take keys without activating the app over the one the user is in.
final class SearchPanel: NSPanel {
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

    override func cancelOperation(_ sender: Any?) { close() }

    /// Centres horizontally and in the upper third of the screen the mouse is on.
    func centerOnMouseScreen() {
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? .main
        guard let frame = screen?.visibleFrame else { return }
        setFrameOrigin(
            NSPoint(x: frame.midX - self.frame.width / 2, y: frame.maxY - frame.height / 3 - self.frame.height))
    }
}
