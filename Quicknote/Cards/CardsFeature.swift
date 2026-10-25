import AppKit
import OSLog
import QuicknoteKit

/// Card editor (S21, S22). The menu, ⌃⌥C, the editor's "Make a card" and the gallery call it.
enum CardsFeature {
    private static let logger = Logger(subsystem: "app.quicknote.Quicknote", category: "Cards")

    /// Opens the card editor with the note's text on a sticky card, or a blank card when `fromNoteId` is nil.
    static func newCard(fromNoteId: Int64?) {
        let saver = CardSaver.live
        let text = fromNoteId.flatMap { try? saver.repository.note(id: $0)?.body }
        CardEditorWindow.show(document: CardEditorModel.startingDocument(text: text), noteId: nil)
    }

    /// Reopens a saved card in the editor.
    static func edit(noteId: Int64) {
        guard let note = try? CardSaver.live.repository.note(id: noteId), let document = note.canvas,
            case .card = document.background
        else { return logger.error("Card \(noteId) cannot be reopened") }
        CardEditorWindow.show(document: document, noteId: noteId)
    }
}
