import Foundation
import ServiceManagement

/// Preferences shared by several features, stored in UserDefaults. Owned by the Settings unit.
enum AppSettings {
    private static let defaults = UserDefaults.standard

    static var showsEdgeOnAllDisplays: Bool {
        get { defaults.object(forKey: "showsEdgeOnAllDisplays") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showsEdgeOnAllDisplays") }
    }

    /// Notes pinned to an app or site slide out when that app or site is in front.
    static var popsUpContextNotes: Bool {
        get { defaults.object(forKey: "popsUpContextNotes") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "popsUpContextNotes") }
    }

    static var defaultNoteColor: String {
        get { defaults.string(forKey: "defaultNoteColor") ?? "#FBE38E" }
        set { defaults.set(newValue, forKey: "defaultNoteColor") }
    }

    /// One of `fontChoices`.
    static var defaultFont: String {
        get { defaults.string(forKey: "defaultFont") ?? "system" }
        set { defaults.set(newValue, forKey: "defaultFont") }
    }

    /// The key Sparkle reads, so this switch and Sparkle never disagree.
    static var checksForUpdatesAutomatically: Bool {
        get { defaults.object(forKey: "SUEnableAutomaticChecks") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "SUEnableAutomaticChecks") }
    }

    /// The system owns this state (Login Items), so it is read back every time.
    static var opensAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            if newValue { try? SMAppService.mainApp.register() } else { try? SMAppService.mainApp.unregister() }
        }
    }

    static let noteColorChoices: [(name: String, hex: String)] = [
        ("Yellow", "#FBE38E"), ("Pink", "#F8C9D4"), ("Green", "#CDEBC6"), ("Blue", "#C8DDF6"), ("Lilac", "#DDD2F4"),
        ("Orange", "#F9D3AC"),
    ]

    static let fontChoices: [(id: String, name: String)] = EditorFont.choices.map { ($0.id, $0.name) }
}
