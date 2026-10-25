import AppKit
import QuicknoteKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests host the app; they must not open the real database or grab global shortcuts.
        guard !AppEnvironment.isRunningTests else { return }
        do {
            try AppEnvironment.start()
        } catch {
            showLaunchFailure(error)
            return
        }
        Shortcuts.register()
        EdgeFeature.start()
        CalendarBridge.shared.resumeSyncingIfAllowed()
        UpdatesFeature.start()
        WelcomeFeature.showIfFirstLaunch()
    }

    private func showLaunchFailure(_ error: any Error) {
        let alert = NSAlert()
        alert.messageText = "Quicknote can't open its notes"
        alert.informativeText =
            "\(error.localizedDescription)\n\nYour notes are in \(AppPaths.live.root.path). Nothing was deleted."
        alert.runModal()
        NSApp.terminate(nil)
    }
}
