import AppKit
import QuicknoteKit
import SwiftUI

/// One borderless panel docked to the right edge of one display, sized to its tabs.
final class EdgePanel: NSPanel {
    private let model: EdgeModel
    private let displayFrame: () -> CGRect
    private var showsCard = false
    private var shrinkTask: Task<Void, Never>?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(screen: NSScreen, model: EdgeModel, actions: EdgeActions) {
        self.model = model
        displayFrame = { [weak screen] in screen?.visibleFrame ?? .zero }
        super.init(
            contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isFloatingPanel = true
        isReleasedWhenClosed = false
        let content = EdgeTabsView(
            model: model, actions: actions, visibleFrame: screen.visibleFrame,
            onCardVisibilityChange: { [weak self] in self?.setShowsCard($0) })
        let hostingView = NSHostingView(rootView: content)
        hostingView.sizingOptions = []
        contentView = hostingView
    }

    func sync() {
        let layout = EdgeLayout(tabCount: model.tabCount, visibleFrame: displayFrame(), showsCard: showsCard)
        guard !model.isHidden, !layout.isEmpty else { return orderOut(nil) }
        setFrame(layout.panelFrame, display: true)
        orderFrontRegardless()
    }

    /// Grows at once, shrinks after the card has slid back so the animation is not cut off.
    private func setShowsCard(_ shows: Bool) {
        shrinkTask?.cancel()
        if shows {
            showsCard = true
            return sync()
        }
        shrinkTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            showsCard = false
            sync()
        }
    }
}
