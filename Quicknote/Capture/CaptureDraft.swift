import Foundation
import QuicknoteKit

/// What is in the capture panel, and how it becomes a note.
struct CaptureDraft {
    /// The order ⇥ cycles through. `context` notes only come from Save where you stopped.
    static let cycleOrder = NoteKind.allCases.filter { $0 != .context }

    var text = ""
    var manualKind: NoteKind?
    var colorHex = AppSettings.defaultNoteColor
    var projectId: Int64?
    var pinsToContext = false
    var context: CapturedContext?
    var attachments: [URL] = []

    var isEmpty: Bool { text.allSatisfy(\.isWhitespace) && attachments.isEmpty }

    func classification(now: Date, calendar: Calendar) -> Classification {
        var result = EntryClassifier.classify(text, now: now, calendar: calendar)
        if let manualKind { result.kind = manualKind }
        return result
    }

    /// Moves to the next type after the one shown. The choice then sticks.
    mutating func cycleKind(now: Date, calendar: Calendar) {
        let shown = classification(now: now, calendar: calendar).kind
        let index = Self.cycleOrder.firstIndex(of: shown) ?? -1
        manualKind = Self.cycleOrder[(index + 1) % Self.cycleOrder.count]
    }

    func makeNote(now: Date, calendar: Calendar) -> Note {
        let classification = classification(now: now, calendar: calendar)
        let link = pastedLink(now: now, calendar: calendar)
        var note = Note(body: link?.body ?? text.trimmingCharacters(in: .whitespacesAndNewlines), now: now)
        note.kind = classification.kind
        note.dueAt = classification.due
        note.dueHasTime = classification.hasTime
        note.recurrence = classification.recurrence
        note.color = colorHex
        note.font = AppSettings.defaultFont
        note.projectId = projectId
        note.appBundleId = context?.appBundleId
        note.appName = context?.appName
        note.siteHost = context?.siteHost
        note.url = link?.url ?? context?.url
        note.pinnedToContext = pinsToContext && context != nil
        return note
    }

    /// A text that is only a link gets its host as the title: no network fetch, so no page title.
    private func pastedLink(now: Date, calendar: Calendar) -> (body: String, url: String)? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let detected = EntryClassifier.classify(trimmed, now: now, calendar: calendar)
        guard detected.kind == .bookmark, let host = URL(string: trimmed)?.host else { return nil }
        return ("\(host)\n\(trimmed)", trimmed)
    }
}
