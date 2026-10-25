import AppKit
import QuicknoteKit

/// Follows the app (and browser page) the user was last in, ignoring Quicknote itself.
final class FrontmostTracker {
    static let shared = FrontmostTracker()
    private static let pagePollInterval = Duration.seconds(3)

    private(set) var context: CapturedContext?
    var onChange: ((CapturedContext) -> Void)?
    private var isStarted = false

    func start() {
        guard !isStarted else { return }
        isStarted = true
        refresh(mayPrompt: false)
        Task { await watchActivations() }
        Task { await pollBrowserPage() }
    }

    /// Reads what is in front now. `mayPrompt` is true only for a user action such as a capture.
    @discardableResult
    func refresh(mayPrompt: Bool) -> CapturedContext? {
        guard let app = NSWorkspace.shared.frontmostApplication, let bundleId = app.bundleIdentifier,
            bundleId != Bundle.main.bundleIdentifier
        else { return context }
        var next = CapturedContext(appBundleId: bundleId, appName: app.localizedName)
        next.url = BrowserURLReader.currentURL(of: app, mayPrompt: mayPrompt)
        next.siteHost = SiteHost.host(from: next.url)
        guard next != context else { return context }
        context = next
        onChange?(next)
        return next
    }

    private func watchActivations() async {
        for await _ in NSWorkspace.shared.notificationCenter.notifications(
            named: NSWorkspace.didActivateApplicationNotification
        ).map({ _ in }) {
            refresh(mayPrompt: false)
        }
    }

    /// A page changes without the app changing, so a browser in front is re-read while pinned notes can pop up.
    private func pollBrowserPage() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: Self.pagePollInterval)
            let isBrowser = context?.appBundleId.flatMap(BrowserURLStrategy.strategy(forBundleId:)) != nil
            if isBrowser, AppSettings.popsUpContextNotes { refresh(mayPrompt: false) }
        }
    }
}
