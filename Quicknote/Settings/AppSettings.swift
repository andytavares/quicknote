import Foundation

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

    static var defaultFont: String {
        get { defaults.string(forKey: "defaultFont") ?? "system" }
        set { defaults.set(newValue, forKey: "defaultFont") }
    }
}
