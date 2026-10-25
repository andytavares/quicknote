import Foundation
import Observation
import QuicknoteKit

/// What the edge shows right now. Pure decisions live in `EdgeFilter` and `EdgeLayout`.
@Observable
final class EdgeModel {
    enum Slot: Identifiable {
        case context, note(Note), overflow(Int)

        var id: String {
            switch self {
            case .context: "context"
            case .note(let note): "note-\(note.id ?? 0)"
            case .overflow: "overflow"
            }
        }
    }

    private(set) var tabNotes: [Note] = []
    private(set) var contextNotes: [Note] = []
    private(set) var contextLabel = ""
    var isContextCardShown = false
    var expandedNoteId: Int64?
    var isHidden = false
    var popsUpContextNotes = true
    private var lastContextKey: ContextKey?

    var tabCount: Int { tabNotes.count + (contextNotes.isEmpty ? 0 : 1) }

    func note(id: Int64) -> Note? { (tabNotes + contextNotes).first { $0.id == id } }

    func update(notes: [Note], context: CapturedContext?, now: Date) {
        let key = context?.key
        let previousCount = contextNotes.count
        contextNotes = popsUpContextNotes ? EdgeFilter.contextNotes(notes, context: key, now: now) : []
        let contextIds = Set(contextNotes.compactMap(\.id))
        tabNotes = EdgeFilter.visibleNotes(notes, context: key, now: now).filter { !contextIds.contains($0.id ?? 0) }
        contextLabel = context?.siteHost ?? context?.appName ?? ""
        let gainedNotes = key != lastContextKey || contextNotes.count > previousCount
        isContextCardShown = !contextNotes.isEmpty && (gainedNotes || isContextCardShown)
        lastContextKey = key
        if let expandedNoteId, note(id: expandedNoteId) == nil { self.expandedNoteId = nil }
    }

    /// A reminder came back: open its card with the bounce.
    func reveal(noteId: Int64) {
        guard note(id: noteId) != nil else { return }
        expandedNoteId = noteId
    }

    func slots(for layout: EdgeLayout) -> [Slot] {
        let all: [Slot] = (contextNotes.isEmpty ? [] : [.context]) + tabNotes.map { .note($0) }
        guard layout.overflowCount > 0 else { return all }
        return Array(all.prefix(layout.tabFrames.count - 1)) + [.overflow(layout.overflowCount)]
    }
}
