import Foundation

/// Permissions that are not allowed, checked at launch and shown in the menu bar menu.
/// Flagged in the menu only, never in a window (decision 5).
@Observable
final class PermissionCheck {
    static let shared = PermissionCheck()

    private(set) var missing: [Permission] = []

    func refresh() async {
        await Permissions.refreshNotificationStatus()
        let statuses = Dictionary(uniqueKeysWithValues: Permission.allCases.map { ($0, Permissions.status(of: $0)) })
        missing = Self.missing(in: statuses)
    }

    /// Mac audio cannot be read before a meeting, so it is missing only once a meeting got no audio.
    static func missing(in statuses: [Permission: PermissionStatus]) -> [Permission] {
        Permission.allCases.filter { permission in
            let status = statuses[permission] ?? .notDetermined
            return permission == .systemAudio ? status == .denied : status != .allowed
        }
    }

    static func summary(of missing: [Permission]) -> String {
        let names = missing.map(\.title).joined(separator: ", ")
        return missing.count == 1 ? "Permission needed: \(names)" : "\(missing.count) permissions needed: \(names)"
    }
}
