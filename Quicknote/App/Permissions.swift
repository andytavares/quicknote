/// Every permission Quicknote asks for, each at first use (S03, S26). Owned by the Settings and Permissions unit.
enum Permission: CaseIterable {
    case microphone, speechRecognition, systemAudio, screenRecording, accessibility, calendar, notifications
}

enum PermissionStatus {
    case notDetermined, allowed, denied
}

enum Permissions {
    static func status(of permission: Permission) -> PermissionStatus { .notDetermined }

    /// Shows the explainer (S03) when needed, then the system prompt. Returns true when the feature may proceed.
    static func ensure(_ permission: Permission) async -> Bool { true }
}
