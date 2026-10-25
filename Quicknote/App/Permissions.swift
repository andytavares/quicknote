import AVFAudio
import AppKit
import ApplicationServices
import CoreGraphics
import EventKit
import Speech
import UserNotifications

/// Every permission Quicknote asks for, each at first use (S03, S26). Owned by the Settings and Permissions unit.
enum Permission: String, CaseIterable {
    case microphone, speechRecognition, systemAudio, screenRecording, accessibility, calendar, notifications
}

enum PermissionStatus {
    case notDetermined, allowed, denied
}

/// What `Permissions.ensure` does next, decided from the status and whether the explainer was already shown.
enum PermissionStep: Equatable {
    case proceed, explainThenRequest, request, explainThenOpenSettings

    static func next(status: PermissionStatus, hasExplained: Bool) -> PermissionStep {
        switch status {
        case .allowed: .proceed
        case .denied: .explainThenOpenSettings
        case .notDetermined: hasExplained ? .request : .explainThenRequest
        }
    }
}

extension Permission {
    /// Verified against the Security & Privacy extension's TCCServiceList.plist and strings on macOS 27.
    var systemSettingsURL: URL {
        let location =
            switch self {
            case .microphone: "com.apple.preference.security?Privacy_Microphone"
            case .speechRecognition: "com.apple.preference.security?Privacy_SpeechRecognition"
            case .systemAudio: "com.apple.preference.security?Privacy_AudioCapture"
            case .screenRecording: "com.apple.preference.security?Privacy_ScreenCapture"
            case .accessibility: "com.apple.preference.security?Privacy_Accessibility"
            case .calendar: "com.apple.preference.security?Privacy_Calendars"
            case .notifications: "com.apple.Notifications-Settings.extension"
            }
        return URL(string: "x-apple.systempreferences:\(location)")!
    }

    /// The name shown in Settings › Permissions.
    var title: String {
        switch self {
        case .microphone: "Microphone"
        case .speechRecognition: "Speech recognition"
        case .systemAudio: "Mac audio for meetings"
        case .screenRecording: "Screen Recording"
        case .accessibility: "Accessibility"
        case .calendar: "Calendar"
        case .notifications: "Notifications"
        }
    }

    /// The pane's name in System Settings, for the explainer's steps.
    var paneName: String {
        switch self {
        case .microphone: "Microphone"
        case .speechRecognition: "Speech Recognition"
        case .systemAudio, .screenRecording: "Screen & System Audio Recording"
        case .accessibility: "Accessibility"
        case .calendar: "Calendars"
        case .notifications: "Notifications"
        }
    }

    var explainerHeadline: String {
        switch self {
        case .microphone: "Hold to talk needs the Microphone"
        case .speechRecognition: "Transcripts need Speech Recognition"
        case .systemAudio: "Meetings need Mac audio"
        case .screenRecording: "Snap needs Screen Recording"
        case .accessibility: "App and site notes need Accessibility"
        case .calendar: "Calendar events need Calendar access"
        case .notifications: "Reminders need Notifications"
        }
    }

    var explainerReason: String {
        switch self {
        case .microphone:
            "Quicknote listens only while you hold the shortcut or record a meeting. Audio stays on this Mac."
        case .speechRecognition: "Voice notes and meetings are turned into text on this Mac. Nothing is sent anywhere."
        case .systemAudio:
            "To transcribe the other people on a call, Quicknote records the sound your Mac plays during a meeting."
        case .screenRecording:
            "macOS asks before any app can read the screen. Quicknote only reads it while you drag to take a Snap, and the image stays on this Mac."
        case .accessibility:
            "Quicknote reads the name of the app or site in front so it can show the notes you pinned to it. It never reads what is on the page."
        case .calendar: "Quicknote adds the events you confirm and reads today's events for the Daily Brief."
        case .notifications: "A reminder you set needs a notification to come back at its time."
        }
    }
}

enum Permissions {
    private static let defaults = UserDefaults.standard
    private static var notificationStatus = PermissionStatus.notDetermined

    static func status(of permission: Permission) -> PermissionStatus {
        switch permission {
        case .microphone: status(AVAudioApplication.shared.recordPermission)
        case .speechRecognition: status(SFSpeechRecognizer.authorizationStatus())
        case .calendar: status(EKEventStore.authorizationStatus(for: .event))
        case .notifications: notificationStatus
        case .screenRecording: unlistedStatus(of: permission, isAllowed: CGPreflightScreenCaptureAccess())
        case .accessibility: unlistedStatus(of: permission, isAllowed: AXIsProcessTrusted())
        case .systemAudio: recordedSystemAudio.map { $0 ? .allowed : .denied } ?? .notDetermined
        }
    }

    /// Notification status is only available asynchronously; call before reading `status(of: .notifications)`.
    static func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus =
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral: .allowed
            case .denied: .denied
            default: .notDetermined
            }
    }

    /// macOS has no way to read Mac audio permission. The meeting recorder reports whether audio arrived.
    static func recordSystemAudioResult(allowed: Bool) {
        defaults.set(allowed, forKey: "systemAudioRecorded")
    }

    /// Shows the explainer (S03) when needed, then the system prompt. Returns true when the feature may proceed.
    static func ensure(_ permission: Permission) async -> Bool {
        await refreshNotificationStatus()
        let hasExplained = defaults.bool(forKey: explainedKey(permission))
        switch PermissionStep.next(status: status(of: permission), hasExplained: hasExplained) {
        case .proceed:
            return true
        case .request:
            return await request(permission)
        case .explainThenRequest:
            guard await PermissionExplainerPanel.show(permission, isDenied: false) else { return false }
            defaults.set(true, forKey: explainedKey(permission))
            return await request(permission)
        case .explainThenOpenSettings:
            if await PermissionExplainerPanel.show(permission, isDenied: true) { open(permission) }
            return false
        }
    }

    static func open(_ permission: Permission) {
        NSWorkspace.shared.open(permission.systemSettingsURL)
    }

    /// Settings › Permissions: the system prompt when possible, otherwise the matching pane.
    static func fix(_ permission: Permission) async {
        await refreshNotificationStatus()
        if status(of: permission) == .notDetermined && permission != .systemAudio {
            _ = await request(permission)
        } else {
            open(permission)
        }
    }

    private static var recordedSystemAudio: Bool? { defaults.object(forKey: "systemAudioRecorded") as? Bool }

    private static func explainedKey(_ permission: Permission) -> String {
        "permissionExplained.\(permission.rawValue)"
    }

    /// Screen Recording and Accessibility cannot tell "never asked" from "refused", so remember that we asked.
    private static func unlistedStatus(of permission: Permission, isAllowed: Bool) -> PermissionStatus {
        if isAllowed { return .allowed }
        return defaults.bool(forKey: requestedKey(permission)) ? .denied : .notDetermined
    }

    private static func requestedKey(_ permission: Permission) -> String {
        "permissionRequested.\(permission.rawValue)"
    }

    private static func request(_ permission: Permission) async -> Bool {
        switch permission {
        case .microphone:
            return await AVAudioApplication.requestRecordPermission()
        case .speechRecognition:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { @Sendable status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        case .systemAudio:
            return true  // macOS asks when the first capture starts; there is nothing to request earlier.
        case .screenRecording:
            defaults.set(true, forKey: requestedKey(permission))
            return CGRequestScreenCaptureAccess()
        case .accessibility:
            defaults.set(true, forKey: requestedKey(permission))
            return AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        case .calendar:
            return (try? await EKEventStore().requestFullAccessToEvents()) ?? false
        case .notifications:
            let granted = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            await refreshNotificationStatus()
            return granted ?? false
        }
    }

    private static func status(_ record: AVAudioApplication.recordPermission) -> PermissionStatus {
        switch record {
        case .granted: .allowed
        case .denied: .denied
        default: .notDetermined
        }
    }

    private static func status(_ speech: SFSpeechRecognizerAuthorizationStatus) -> PermissionStatus {
        switch speech {
        case .authorized: .allowed
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    private static func status(_ calendar: EKAuthorizationStatus) -> PermissionStatus {
        switch calendar {
        case .fullAccess: .allowed
        case .notDetermined: .notDetermined
        default: .denied
        }
    }
}
