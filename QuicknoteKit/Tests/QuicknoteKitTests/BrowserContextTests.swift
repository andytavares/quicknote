import Testing

@testable import QuicknoteKit

struct BrowserContextTests {
    @Test(arguments: [
        ("https://www.figma.com/design/pricing-v3", "figma.com"),
        ("https://Docs.Google.com/document/d/1", "docs.google.com"),
        ("http://localhost:3000/app", "localhost"),
        ("https://wwwx.example.org", "wwwx.example.org"),
    ])
    func siteHostDropsLeadingWww(url: String, host: String) {
        #expect(SiteHost.host(from: url) == host)
    }

    @Test(arguments: [nil, "", "not a url", "about:blank", "file:///Users/me/a.txt"])
    func siteHostIsNilWithoutAWebHost(url: String?) {
        #expect(SiteHost.host(from: url) == nil)
    }

    @Test func browsersMapToTheirAppleEventsScript() {
        #expect(BrowserURLStrategy.strategy(forBundleId: "com.apple.Safari")?.appleEvents == .safari)
        for id in ["com.google.Chrome", "company.thebrowser.Browser", "com.brave.Browser", "com.microsoft.edgemac"] {
            #expect(BrowserURLStrategy.strategy(forBundleId: id)?.appleEvents == .chromium)
        }
    }

    @Test func firefoxIsReadThroughAccessibilityOnly() {
        #expect(
            BrowserURLStrategy.strategy(forBundleId: "org.mozilla.firefox")?.appleEvents
                == BrowserURLStrategy.Script.none)
    }

    @Test func otherAppsAreNotBrowsers() {
        #expect(BrowserURLStrategy.strategy(forBundleId: "com.tinyspeck.slackmacgap") == nil)
    }

    private let chromium = BrowserURLStrategy.strategy(forBundleId: "com.google.Chrome")!
    private let firefox = BrowserURLStrategy.strategy(forBundleId: "org.mozilla.firefox")!

    @Test func backgroundReadsNeverUseASourceThatWouldPrompt() {
        let sources = URLReadPolicy.sources(
            for: chromium, accessibilityTrusted: false, automation: .undetermined, mayPrompt: false)
        #expect(sources.isEmpty)
        let denied = URLReadPolicy.sources(
            for: chromium, accessibilityTrusted: false, automation: .denied, mayPrompt: true)
        #expect(denied.isEmpty)
    }

    @Test func trustedAccessibilityComesFirstThenGrantedAppleEvents() {
        let sources = URLReadPolicy.sources(
            for: chromium, accessibilityTrusted: true, automation: .granted, mayPrompt: false)
        #expect(sources == [.accessibility, .appleEvents])
    }

    @Test func aUserActionMayAskForAutomationOnce() {
        let sources = URLReadPolicy.sources(
            for: chromium, accessibilityTrusted: false, automation: .undetermined, mayPrompt: true)
        #expect(sources == [.appleEvents])
    }

    @Test func firefoxNeverUsesAppleEvents() {
        let sources = URLReadPolicy.sources(
            for: firefox, accessibilityTrusted: true, automation: .granted, mayPrompt: true)
        #expect(sources == [.accessibility])
    }
}
