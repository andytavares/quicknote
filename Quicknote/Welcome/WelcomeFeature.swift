import AppKit
import SwiftUI

/// First-launch welcome window (S02). Owned by the Settings and Permissions unit.
enum WelcomeFeature {
    static let shownKey = "welcomeShown"
    private static var window: NSWindow?

    static func showIfFirstLaunch(defaults: UserDefaults = .standard) {
        guard shouldShow(defaults: defaults) else { return }
        defaults.set(true, forKey: shownKey)
        let window = NSWindow(
            contentRect: .zero, styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        window.contentViewController = NSHostingController(rootView: WelcomeView(close: { window.close() }))
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.center()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    static func shouldShow(defaults: UserDefaults) -> Bool { !defaults.bool(forKey: shownKey) }
}
