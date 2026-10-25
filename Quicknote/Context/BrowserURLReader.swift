import AppKit
import ApplicationServices
import QuicknoteKit

/// Reads the current page of a browser. Never shows an Accessibility prompt; the Automation prompt only
/// when `mayPrompt` is true, which only a user action sets.
enum BrowserURLReader {
    private static let maximumSearchedElements = 400

    static func currentURL(of app: NSRunningApplication, mayPrompt: Bool) -> String? {
        guard let bundleId = app.bundleIdentifier, let strategy = BrowserURLStrategy.strategy(forBundleId: bundleId)
        else { return nil }
        let sources = URLReadPolicy.sources(
            for: strategy, accessibilityTrusted: AXIsProcessTrusted(),
            automation: automationAccess(bundleId: bundleId), mayPrompt: mayPrompt)
        for source in sources {
            let url =
                switch source {
                case .accessibility: accessibilityURL(processId: app.processIdentifier)
                case .appleEvents: appleEventsURL(bundleId: bundleId, script: strategy.appleEvents)
                }
            if let url { return url }
        }
        return nil
    }

    /// Asks the system without prompting (`askUserIfNeeded: false`).
    private static func automationAccess(bundleId: String) -> AutomationAccess {
        let target = NSAppleEventDescriptor(bundleIdentifier: bundleId)
        guard let descriptor = target.aeDesc else { return .denied }
        let status = AEDeterminePermissionToAutomateTarget(descriptor, typeWildCard, typeWildCard, false)
        switch status {
        case noErr: return .granted
        case OSStatus(errAEEventWouldRequireUserConsent): return .undetermined
        default: return .denied
        }
    }

    private static func accessibilityURL(processId: pid_t) -> String? {
        let application = AXUIElementCreateApplication(processId)
        AXUIElementSetMessagingTimeout(application, 0.5)
        guard let window = attribute(kAXFocusedWindowAttribute, of: application) else { return nil }
        var queue = [window as! AXUIElement]
        var visited = 0
        while !queue.isEmpty, visited < maximumSearchedElements {
            let element = queue.removeFirst()
            visited += 1
            if attribute(kAXRoleAttribute, of: element) as? String == "AXWebArea",
                let url = attribute(kAXURLAttribute, of: element) as? URL
            {
                return url.absoluteString
            }
            queue += (attribute(kAXChildrenAttribute, of: element) as? [AXUIElement]) ?? []
        }
        return nil
    }

    private static func attribute(_ name: String, of element: AXUIElement) -> AnyObject? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    /// NSAppleScript must run on the main thread, so the whole reader does.
    private static func appleEventsURL(bundleId: String, script: BrowserURLStrategy.Script) -> String? {
        let target: String? =
            switch script {
            case .safari: "URL of front document"
            case .chromium: "URL of active tab of front window"
            case .none: nil
            }
        guard let target else { return nil }
        let source = "with timeout of 1 seconds\ntell application id \"\(bundleId)\" to return \(target)\nend timeout"
        return NSAppleScript(source: source)?.executeAndReturnError(nil).stringValue
    }
}
