import SwiftUI

@main
struct QuicknoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarMenu()
        } label: {
            Image("MenuBarIcon").accessibilityLabel("Quicknote")
        }
        Settings {
            SettingsView()
        }
    }
}
