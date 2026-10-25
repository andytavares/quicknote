import Foundation

public enum SiteHost {
    /// The web host of `url` without a leading "www."; nil for anything that is not an http(s) page.
    public static func host(from url: String?) -> String? {
        guard let url, let components = URLComponents(string: url),
            ["http", "https"].contains(components.scheme?.lowercased()), let host = components.host, !host.isEmpty
        else { return nil }
        return host.lowercased().replacing(/^www\./, with: "")
    }
}

/// How to read the current page of a browser, found by bundle id.
public struct BrowserURLStrategy: Equatable, Sendable {
    public enum Script: Equatable, Sendable {
        case safari, chromium, none
    }

    public var appleEvents: Script

    /// Nil when `bundleId` is not a supported browser.
    public static func strategy(forBundleId bundleId: String) -> BrowserURLStrategy? {
        switch bundleId {
        case "com.apple.Safari", "com.apple.SafariTechnologyPreview": BrowserURLStrategy(appleEvents: .safari)
        case "com.google.Chrome", "company.thebrowser.Browser", "com.brave.Browser", "com.microsoft.edgemac":
            BrowserURLStrategy(appleEvents: .chromium)
        case "org.mozilla.firefox": BrowserURLStrategy(appleEvents: .none)
        default: nil
        }
    }
}

public enum URLSource: Equatable, Sendable {
    case accessibility, appleEvents
}

public enum AutomationAccess: Equatable, Sendable {
    case granted, undetermined, denied
}

/// Decides which sources may be read without showing a system prompt the user did not ask for.
public enum URLReadPolicy {
    /// Accessibility is used only when already trusted; the app never asks for it here.
    /// Apple Events are used when already granted, or when undetermined and `mayPrompt` (a user action).
    public static func sources(
        for strategy: BrowserURLStrategy, accessibilityTrusted: Bool, automation: AutomationAccess, mayPrompt: Bool
    ) -> [URLSource] {
        var sources: [URLSource] = []
        if accessibilityTrusted { sources.append(.accessibility) }
        let appleEventsAllowed = automation == .granted || (automation == .undetermined && mayPrompt)
        if strategy.appleEvents != .none, appleEventsAllowed { sources.append(.appleEvents) }
        return sources
    }
}
