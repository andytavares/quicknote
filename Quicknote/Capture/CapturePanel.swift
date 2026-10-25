import AppKit
import SwiftUI

/// Floating panel that takes keys without activating Quicknote's other windows, also over full-screen apps.
final class CapturePanel: NSPanel {
    override var canBecomeKey: Bool { true }

    init<Content: View>(rootView: Content) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 200),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = NSHostingView(rootView: rootView)
    }

    override func cancelOperation(_ sender: Any?) { close() }

    func showCentered() {
        if let size = contentView?.fittingSize { setContentSize(size) }
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? .main
        if let frame = screen?.visibleFrame {
            setFrameOrigin(
                NSPoint(x: frame.midX - self.frame.width / 2, y: frame.maxY - frame.height / 3 - self.frame.height))
        }
        makeKeyAndOrderFront(nil)
    }
}
