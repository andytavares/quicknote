import AppKit
import KeyboardShortcuts
import Observation
import SwiftUI

@Observable
final class HoldToTalkHUDModel {
    enum Phase: Equatable {
        case preparing, listening, finishing
        case saved(title: String, detail: String)
        case error(String)
    }

    var phase = Phase.preparing
    var text = ""
    var chip: String?
    var level: Float = 0
    var undo: (() -> Void)?
}

/// The floating panel for S05. It never takes focus, so the app you are talking about stays in front.
final class HoldToTalkHUD: HoldToTalkPresenting {
    private static let dismissDelay: Duration = .seconds(4)

    private let model = HoldToTalkHUDModel()
    private var panel: NSPanel?
    private var dismissal: Task<Void, Never>?

    func showPreparing() { show(.preparing, announce: "Getting ready") }

    func showListening() {
        model.text = ""
        model.chip = nil
        show(.listening, announce: "Listening")
    }

    func showFinishing() { show(.finishing, announce: "Saving") }

    func showLive(text: String, chip: String?) {
        model.text = text
        model.chip = chip
        resize()
    }

    func showLevel(_ level: Float) { model.level = level }

    func showSaved(title: String, detail: String, undo: @escaping () -> Void) {
        model.undo = { [weak self] in
            undo()
            self?.hide()
        }
        show(.saved(title: title, detail: detail), announce: "Saved. \(title). \(detail)")
        hideAfterDelay()
    }

    func showError(_ message: String) {
        show(.error(message), announce: message)
        hideAfterDelay()
    }

    func hide() {
        dismissal?.cancel()
        panel?.orderOut(nil)
    }

    private func show(_ phase: HoldToTalkHUDModel.Phase, announce message: String) {
        dismissal?.cancel()
        model.phase = phase
        let panel = panel ?? makePanel()
        self.panel = panel
        resize()
        panel.orderFrontRegardless()
        NSAccessibility.post(
            element: panel, notification: .announcementRequested,
            userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    private func hideAfterDelay() {
        dismissal = Task { [weak self] in
            try? await Task.sleep(for: Self.dismissDelay)
            if !Task.isCancelled { self?.hide() }
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: HoldToTalkHUDView(model: model))
        return panel
    }

    private func resize() {
        guard let panel, let view = panel.contentView, let screen = NSScreen.main else { return }
        let size = view.fittingSize
        let frame = screen.visibleFrame
        panel.setFrame(
            NSRect(
                x: frame.midX - size.width / 2, y: frame.maxY - size.height - 80, width: size.width, height: size.height
            ),
            display: true)
    }
}

struct HoldToTalkHUDView: View {
    let model: HoldToTalkHUDModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch model.phase {
            case .preparing: header("Getting ready…", color: .secondary, hint: "first use downloads English speech")
            case .listening: listening
            case .finishing: header("Saving…", color: .secondary)
            case .saved(let title, let detail): saved(title: title, detail: detail)
            case .error(let message): header("Could not listen", color: .red, hint: message)
            }
        }
        .frame(width: model.phase.isSaved ? 300 : 460, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .contain)
    }

    private var listening: some View {
        VStack(alignment: .leading, spacing: 0) {
            listeningHeader
            Text(model.text)
                .font(.system(size: 15))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
                .accessibilityLabel("Heard so far: \(model.text)")
            Divider()
            listeningFooter
        }
    }

    private var listeningHeader: some View {
        HStack(spacing: 8) {
            Circle().fill(.red).frame(width: 9, height: 9)
            Text("Listening").bold()
            Text("release \(shortcutName) to save").font(.caption).foregroundStyle(.secondary)
            Spacer()
            LevelMeter(level: model.level)
        }
        .padding(14)
    }

    private var listeningFooter: some View {
        HStack {
            if let chip = model.chip {
                Text(chip).font(.caption).padding(.horizontal, 8).padding(.vertical, 3).background(
                    .tint.opacity(0.2), in: Capsule())
            }
            Spacer()
            Text("On this Mac").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private func saved(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Circle().fill(.green).frame(width: 9, height: 9)
                Text("Saved").bold()
                Spacer()
                Button("Undo") { model.undo?() }.accessibilityHint("Deletes the note you just saved")
            }
            Text(title).font(.callout)
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .padding(14)
    }

    private func header(_ title: String, color: Color, hint: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Circle().fill(color).frame(width: 9, height: 9)
                Text(title).bold()
            }
            if let hint { Text(hint).font(.caption).foregroundStyle(.secondary) }
        }
        .padding(14)
    }

    private var shortcutName: String {
        KeyboardShortcuts.getShortcut(for: .holdToTalk)?.description ?? "the shortcut"
    }
}

private struct LevelMeter: View {
    private static let shape: [CGFloat] = [10, 22, 14, 28, 18, 24, 9, 20, 13, 26]
    let level: Float

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Self.shape.indices, id: \.self) { index in
                Capsule().fill(.tint).frame(width: 3, height: max(3, Self.shape[index] * CGFloat(level)))
            }
        }
        .frame(height: 28)
        .accessibilityHidden(true)
    }
}

extension HoldToTalkHUDModel.Phase {
    fileprivate var isSaved: Bool {
        if case .saved = self { return true }
        return false
    }
}
