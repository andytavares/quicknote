import Foundation
import Observation
import QuicknoteKit

/// State behind the capture panel. It outlives the panel, so Esc keeps the draft for next time.
@Observable
final class CaptureModel {
    var draft = CaptureDraft()
    var projects: [Project] = []
    var onClose: () -> Void = {}

    var detectedChip: String {
        let note = draft.makeNote(now: Date(), calendar: .current)
        return VoiceNote.chip(for: note, now: Date(), calendar: .current)
    }

    /// Called each time the panel opens, with the context read before the panel appeared.
    func prepare(context: CapturedContext?) {
        draft.context = context
        if context == nil { draft.pinsToContext = false }
        projects = (try? ProjectRepository(database: AppEnvironment.current.database).all()) ?? []
    }

    func cycleKind() { draft.cycleKind(now: Date(), calendar: .current) }

    func attach(_ urls: [URL]) { draft.attachments.append(contentsOf: urls) }

    func save() {
        guard !draft.isEmpty else { return }
        let environment = AppEnvironment.current
        var note = draft.makeNote(now: Date(), calendar: .current)
        guard (try? NoteRepository(database: environment.database).save(&note, now: Date())) != nil,
            let noteId = note.id
        else { return }
        let files = draft.attachments
        Task { await AttachmentImporter.importFiles(files, toNoteId: noteId) }
        if note.kind == .event && note.dueHasTime { CalendarConfirmation.present(forNoteId: noteId) }
        draft = CaptureDraft()
        onClose()
    }
}
