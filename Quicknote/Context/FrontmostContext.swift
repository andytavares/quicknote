import QuicknoteKit

/// The app, and for browsers the page, that was in front when something was captured.
struct CapturedContext: Equatable {
    var appBundleId: String?
    var appName: String?
    var siteHost: String?
    var url: String?

    var key: ContextKey { ContextKey(appBundleId: appBundleId, siteHost: siteHost) }
}

enum FrontmostContext {
    /// The context in front right now, ignoring Quicknote's own windows. May ask for Automation once per browser.
    static func current() async -> CapturedContext? {
        FrontmostTracker.shared.refresh(mayPrompt: true)
    }
}

extension Note {
    /// Records where the note was captured. A pasted link's address, set later, may replace `url`.
    mutating func remember(_ context: CapturedContext?) {
        appBundleId = context?.appBundleId
        appName = context?.appName
        siteHost = context?.siteHost
        url = context?.url
    }
}
