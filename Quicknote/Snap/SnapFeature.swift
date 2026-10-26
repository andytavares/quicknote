import AppKit
import OSLog
import QuicknoteKit

/// Snap selection and editor (S19, S20). The shortcut calls `start()`.
enum SnapFeature {
    private static var overlay: SnapOverlay?
    private static var pendingSave: Task<Int64?, Never>?
    private static let logger = Logger(subsystem: "app.quicknote.Quicknote", category: "Snap")

    static func start() {
        guard overlay == nil else { return }
        Task {
            guard await Permissions.ensure(.screenRecording) else { return }
            let newOverlay = SnapOverlay(
                onCapture: { image in pendingSave = startSaving(image) },
                onAction: { image, action in
                    overlay = nil
                    let save = pendingSave
                    Task { perform(action, on: image, noteId: await save?.value) }
                })
            overlay = newOverlay
            newOverlay.show()
        }
    }

    /// Reopens a saved Snap in the editor.
    static func edit(noteId: Int64) {
        SnapEditorWindow.reopen(noteId: noteId)
    }

    /// `noteId` is the note the capture was already saved as, so Mark up edits it instead of making another.
    private static func perform(_ action: SnapAction, on image: CGImage, noteId: Int64?) {
        switch action {
        case .markUp:
            SnapEditorWindow.show(original: image, document: SnapSaver.blankDocument(for: image), noteId: noteId)
        case .saveToEdge: break
        case .copy:
            let payload = SharePayload(image: image, caption: "", noteId: noteId ?? 0)
            ShareActions.copyImage(of: payload)
        }
    }

    private static func startSaving(_ image: CGImage) -> Task<Int64?, Never> {
        Task {
            do {
                return try await SnapSaver.live.saveCapture(image, now: Date())
            } catch {
                logger.error("Saving a Snap failed: \(error)")
                return nil
            }
        }
    }
}
