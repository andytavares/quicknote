import Foundation
import OSLog
import QuicknoteKit

/// What a tab or card can do to its note. Every change goes through `NoteRepository.save`.
struct EdgeActions {
    let repository: NoteRepository
    private let logger = Logger(subsystem: "app.quicknote.Quicknote", category: "Edge")

    func done(_ note: Note) {
        change(note) { ReminderAction.done.apply(to: $0, now: $1, calendar: .current) }
    }

    func snooze(_ note: Note, until date: Date) {
        change(note) { note, _ in note.snoozed(until: date) }
    }

    func removeFromEdge(_ note: Note) {
        change(note) { note, _ in
            var removed = note
            removed.onEdge = false
            return removed
        }
    }

    func openInLibrary(_ note: Note) {
        guard let noteId = note.id else { return }
        LibraryFeature.open(noteId: noteId)
    }

    private func change(_ note: Note, _ transform: (Note, Date) -> Note) {
        let now = Date()
        var changed = transform(note, now)
        do { try repository.save(&changed, now: now) } catch { logger.error("Saving a note failed: \(error)") }
    }
}
