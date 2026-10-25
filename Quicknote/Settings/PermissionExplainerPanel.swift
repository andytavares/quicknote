import AppKit
import SwiftUI

/// The explainer card (S03) shown before a system prompt, or in place of one after a refusal.
enum PermissionExplainerPanel {
    /// Returns true when the person pressed the primary button.
    static func show(_ permission: Permission, isDenied: Bool) async -> Bool {
        await withCheckedContinuation { continuation in
            let panel = NSPanel(
                contentRect: .zero, styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered,
                defer: false)
            var answered = false
            let answer: (Bool) -> Void = { result in
                guard !answered else { return }
                answered = true
                panel.close()
                continuation.resume(returning: result)
            }
            panel.contentViewController = NSHostingController(
                rootView: PermissionExplainerView(permission: permission, isDenied: isDenied, answer: answer))
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isFloatingPanel = true
            panel.isReleasedWhenClosed = false
            panel.center()
            NSApp.activate()
            panel.makeKeyAndOrderFront(nil)
        }
    }
}

private struct PermissionExplainerView: View {
    let permission: Permission
    let isDenied: Bool
    let answer: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(permission.explainerHeadline).font(.headline)
            Text(permission.explainerReason).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if isDenied { steps }
            HStack {
                Spacer()
                Button("Not now") { answer(false) }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityLabel("Not now")
                Button(isDenied ? "Open System Settings" : "Continue") { answer(true) }
                    .keyboardShortcut(.defaultAction)
                    .accessibilityLabel(isDenied ? "Open System Settings" : "Continue to the system prompt")
            }
        }
        .padding(20)
        .frame(width: 400)
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("1  Click Open System Settings")
            Text("2  Turn on Quicknote under \(permission.paneName)")
            Text("3  Come back and try again")
        }
        .font(.callout)
    }
}
