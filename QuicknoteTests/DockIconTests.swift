import AppKit
import Testing

@testable import Quicknote

@MainActor
struct DockIconTests {
    @Test func aVisibleWindowKeepsTheDockIcon() {
        let window = makeWindow(NSWindow.self)
        window.orderFront(nil)
        defer { window.close() }

        #expect(DockIcon.isNeeded(among: [window]))
    }

    @Test func hiddenWindowsAndPanelsDoNotKeepTheDockIcon() {
        let hidden = makeWindow(NSWindow.self)
        let panel = makeWindow(NSPanel.self)
        panel.orderFront(nil)
        defer { panel.close() }

        #expect(!DockIcon.isNeeded(among: [hidden, panel]))
    }

    private func makeWindow<Window: NSWindow>(_ type: Window.Type) -> Window {
        let window = Window(
            contentRect: CGRect(x: 0, y: 0, width: 100, height: 100), styleMask: [.titled], backing: .buffered,
            defer: false)
        window.isReleasedWhenClosed = false
        return window
    }
}
