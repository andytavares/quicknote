import QuicknoteKit

/// The app, and for browsers the page, that was in front when something was captured.
struct CapturedContext: Equatable {
    var appBundleId: String?
    var appName: String?
    var siteHost: String?
    var url: String?

    var key: ContextKey { ContextKey(appBundleId: appBundleId, siteHost: siteHost) }
}

/// Owned by the Edge unit, which implements app and browser detection.
enum FrontmostContext {
    /// The context in front right now, ignoring Quicknote's own windows.
    static func current() async -> CapturedContext? { nil }
}
