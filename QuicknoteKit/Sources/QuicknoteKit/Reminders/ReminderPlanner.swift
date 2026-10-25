import Foundation

/// A system notification Quicknote wants scheduled.
public struct PlannedAlert: Equatable, Sendable {
    public var noteId: Int64
    public var fireAt: Date
    public var title: String
    public var body: String

    public init(noteId: Int64, fireAt: Date, title: String, body: String) {
        self.noteId = noteId
        self.fireAt = fireAt
        self.title = title
        self.body = body
    }
}

/// Decides what Quicknote alerts you about: only things you set a time on, or snoozed.
public enum ReminderPlanner {
    static let timedKinds: Set<NoteKind> = [.reminder, .task, .event, .todoList]
    /// Kinds listed under "due" in the Daily Brief (events come from the calendar).
    static let briefKinds: Set<NoteKind> = [.reminder, .task, .todoList]

    public static func plannedAlerts(for notes: [Note], now: Date) -> [PlannedAlert] {
        notes.compactMap { alert(for: $0, now: now) }.sorted { $0.fireAt < $1.fireAt }
    }

    /// Open notes whose snooze ends inside `interval`, soonest first.
    public static func notesComingBack(_ notes: [Note], between interval: DateInterval) -> [Note] {
        notes
            .filter { $0.completedAt == nil && $0.snoozedUntil.map(interval.contains) == true }
            .sorted { $0.snoozedUntil! < $1.snoozedUntil! }
    }

    private static func alert(for note: Note, now: Date) -> PlannedAlert? {
        guard let noteId = note.id, note.completedAt == nil else { return nil }
        if let snoozedUntil = note.snoozedUntil, snoozedUntil > now {
            return PlannedAlert(noteId: noteId, fireAt: snoozedUntil, title: note.title, body: "Back from snooze")
        }
        guard timedKinds.contains(note.kind), note.dueHasTime, let dueAt = note.dueAt, dueAt > now else {
            return nil
        }
        return PlannedAlert(noteId: noteId, fireAt: dueAt, title: note.title, body: "Due now")
    }
}
