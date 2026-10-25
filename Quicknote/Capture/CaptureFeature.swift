import AppKit
import SwiftUI

/// Quick capture (S04) and Save where you stopped (S09). Owned by the Capture unit.
enum CaptureFeature {
    private static let captureModel = CaptureModel()
    private static let stopModel = StopModel()
    private static var capturePanel: KeyPanel?
    private static var stopPanel: KeyPanel?

    /// ⌃⌥N. The context is read first, so it is the app you were in and not Quicknote.
    static func showPanel() {
        Task {
            captureModel.prepare(context: await FrontmostContext.current())
            let panel = capturePanel ?? KeyPanel(rootView: CaptureView(model: captureModel))
            captureModel.onClose = { panel.close() }
            capturePanel = panel
            panel.showCentered()
        }
    }

    /// ⌃⌥S. Only when asked: nothing shows this on wake or unlock.
    static func showSaveContext() {
        Task {
            stopModel.prepare(context: await FrontmostContext.current())
            let panel = stopPanel ?? KeyPanel(rootView: StopView(model: stopModel))
            stopModel.onClose = { panel.close() }
            stopPanel = panel
            panel.showCentered()
        }
    }
}
