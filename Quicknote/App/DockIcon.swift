import AppKit

/// Quicknote lives in the menu bar. It shows a Dock icon only while the Library or Settings is open.
enum DockIcon {
    /// A menu bar app can be refused activation, so its window opens behind others; a regular app is not.
    static func show() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    /// Hides the Dock icon again when the last window closes.
    static func start() {
        Task {
            for await notification in NotificationCenter.default.notifications(named: NSWindow.willCloseNotification) {
                let closing = notification.object as? NSWindow
                if !isNeeded(among: NSApp.windows.filter { $0 !== closing }) {
                    NSApp.setActivationPolicy(.accessory)
                }
            }
        }
    }

    /// Only titled windows count: the menu bar icon's own window is borderless and always visible.
    static func isNeeded(among windows: [NSWindow]) -> Bool {
        windows.contains { $0.isVisible && !($0 is NSPanel) && $0.styleMask.contains(.titled) }
    }
}
