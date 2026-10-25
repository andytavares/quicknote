import AppKit
import Sparkle

/// Sparkle updates. Only Release builds with a real public key update; Debug builds never do.
enum UpdatesFeature {
    private static var controller: SPUStandardUpdaterController?

    static func start() {
        #if !DEBUG
            guard !AppEnvironment.isRunningTests, updatesAreEnabled(publicKey: configuredPublicKey) else { return }
            controller = SPUStandardUpdaterController(
                startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        #endif
    }

    static func checkForUpdates() {
        guard let controller else { return showDevelopmentBuildAlert() }
        controller.checkForUpdates(nil)
    }

    /// A real Sparkle key is base64 of 32 bytes (44 characters); the placeholder is not base64.
    static func updatesAreEnabled(publicKey: String?) -> Bool {
        guard let key = publicKey?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else {
            return false
        }
        return Data(base64Encoded: key) != nil
    }

    private static var configuredPublicKey: String? {
        Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
    }

    private static func showDevelopmentBuildAlert() {
        let alert = NSAlert()
        alert.messageText = "Updates are off in development builds"
        alert.informativeText = "Install a released build of Quicknote to get updates."
        alert.runModal()
    }
}
