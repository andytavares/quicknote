import AppKit
import OSLog
import SwiftUI

enum SnapAction { case markUp, saveToEdge, copy }

/// The dimmed selection overlay (S19): one window per display. A drag captures the rect on release, then an
/// action bar by the selection offers Mark up, Save to edge and Copy.
final class SnapOverlay {
    private let logger = Logger(subsystem: "app.quicknote.Quicknote", category: "Snap")
    private var windows: [SnapOverlayWindow] = []
    private let onCapture: (CGImage) -> Void
    private let onAction: (CGImage, SnapAction) -> Void

    init(onCapture: @escaping (CGImage) -> Void, onAction: @escaping (CGImage, SnapAction) -> Void) {
        self.onCapture = onCapture
        self.onAction = onAction
    }

    func show() {
        windows = NSScreen.screens.compactMap { screen in
            guard let display = SnapDisplay(screen) else { return nil }
            let window = SnapOverlayWindow(
                contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.contentView = SnapSelectionView(display: display, overlay: self)
            window.setFrame(screen.frame, display: false)
            window.makeKeyAndOrderFront(nil)
            return window
        }
        NSApp.activate()
    }

    func close() {
        windows.forEach { $0.close() }
        windows = []
    }

    fileprivate func finishSelection(in view: SnapSelectionView, rect: CGRect) {
        guard let window = view.window else { return }
        let global = window.convertToScreen(view.convert(rect, to: nil))
        let request = SnapCaptureRequest.make(selection: global, on: view.display)
        let overlayIDs = windows.map { CGWindowID($0.windowNumber) }
        Task {
            do {
                let image = try await SnapCapture.capture(request, excludingWindowIDs: overlayIDs)
                onCapture(image)
                view.showActions { [self] action in
                    close()
                    onAction(image, action)
                }
            } catch {
                logger.error("Snap capture failed: \(error)")
                close()
            }
        }
    }
}

private final class SnapOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

private final class SnapSelectionView: NSView {
    let display: SnapDisplay
    private unowned let overlay: SnapOverlay
    private var anchor: CGPoint?
    private var selection: CGRect?
    private var isLocked = false

    init(display: SnapDisplay, overlay: SnapOverlay) {
        self.display = display
        self.overlay = overlay
        super.init(frame: .zero)
        setAccessibilityLabel("Snap selection. Drag to capture, Escape to cancel.")
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var acceptsFirstResponder: Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }
    override func viewDidMoveToWindow() { window?.makeFirstResponder(self) }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { overlay.close() } else { super.keyDown(with: event) }
    }

    override func mouseDown(with event: NSEvent) {
        guard !isLocked else { return }
        anchor = convert(event.locationInWindow, from: nil)
        selection = nil
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard !isLocked, let anchor else { return }
        let point = convert(event.locationInWindow, from: nil)
        selection = CGRect(
            x: min(anchor.x, point.x), y: min(anchor.y, point.y), width: abs(point.x - anchor.x),
            height: abs(point.y - anchor.y))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard !isLocked, let selection, selection.width >= 4, selection.height >= 4 else {
            selection = nil
            needsDisplay = true
            return
        }
        isLocked = true
        overlay.finishSelection(in: self, rect: selection)
    }

    override func draw(_ dirtyRect: NSRect) {
        let dim = NSBezierPath(rect: bounds)
        if let selection { dim.append(NSBezierPath(rect: selection)) }
        dim.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.4).setFill()
        dim.fill()
        guard let selection else {
            return drawLabel("Drag to capture · Esc to cancel", at: CGPoint(x: bounds.midX, y: bounds.midY))
        }
        NSColor.white.setStroke()
        NSBezierPath(rect: selection).stroke()
        let pixels = "\(Int(selection.width * display.scale)) × \(Int(selection.height * display.scale))"
        drawLabel(pixels, at: CGPoint(x: selection.midX, y: selection.maxY + 14))
    }

    private func drawLabel(_ text: String, at centre: CGPoint) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium), .foregroundColor: NSColor.white,
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let box = CGRect(
            x: centre.x - size.width / 2 - 8, y: centre.y - size.height / 2 - 3, width: size.width + 16,
            height: size.height + 6)
        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: box, xRadius: 6, yRadius: 6).fill()
        (text as NSString).draw(at: CGPoint(x: box.minX + 8, y: box.minY + 3), withAttributes: attributes)
    }

    func showActions(_ choose: @escaping (SnapAction) -> Void) {
        guard let selection else { return }
        let bar = NSHostingView(rootView: SnapActionBar(choose: choose))
        let size = bar.fittingSize
        let below = selection.minY - size.height - 8
        let originY = below >= 0 ? below : min(selection.maxY + 8, bounds.maxY - size.height)
        bar.frame = CGRect(
            x: min(max(selection.minX, 8), bounds.maxX - size.width - 8), y: originY, width: size.width,
            height: size.height)
        addSubview(bar)
        window?.makeFirstResponder(self)
    }
}

private struct SnapActionBar: View {
    let choose: (SnapAction) -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button("Mark up") { choose(.markUp) }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Mark up the Snap")
            Button("Save to edge") { choose(.saveToEdge) }
                .accessibilityLabel("Save the Snap to the edge")
            Button("Copy") { choose(.copy) }
                .accessibilityLabel("Copy the Snap image")
        }
        .controlSize(.regular)
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
