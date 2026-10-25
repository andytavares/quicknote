import AppKit
import OSLog
import QuicknoteKit

/// Snap selection and editor (S19, S20). The shortcut calls `start()`.
enum SnapFeature {
    private static var overlay: SnapOverlay?
    private static let logger = Logger(subsystem: "app.quicknote.Quicknote", category: "Snap")

    static func start() {
        guard overlay == nil else { return }
        Task {
            guard await Permissions.ensure(.screenRecording) else { return }
            let newOverlay = SnapOverlay { image, action in
                overlay = nil
                perform(action, on: image)
            }
            overlay = newOverlay
            newOverlay.show()
        }
    }

    /// Reopens a saved Snap in the editor.
    static func edit(noteId: Int64) {
        SnapEditorWindow.reopen(noteId: noteId)
    }

    private static func perform(_ action: SnapAction, on image: CGImage) {
        let size = CGSize(width: image.width, height: image.height)
        let document = CanvasDocument(background: .image(attachmentId: 0, size: size))
        switch action {
        case .markUp: SnapEditorWindow.show(original: image, document: document, noteId: nil)
        case .saveToEdge: saveToEdge(image, document)
        case .copy:
            let payload = SharePayload(image: image, caption: "", noteId: 0)
            ShareActions.copyImage(of: payload)
        }
    }

    private static func saveToEdge(_ image: CGImage, _ document: CanvasDocument) {
        Task {
            do {
                _ = try await SnapSaver.live.save(
                    SnapContent(original: image, document: document), noteId: nil, now: Date())
            } catch {
                logger.error("Saving a Snap failed: \(error)")
            }
        }
    }
}
