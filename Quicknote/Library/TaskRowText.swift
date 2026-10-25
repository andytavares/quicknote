import Foundation
import QuicknoteKit

extension TaskGrouper {
    /// The grey line under a title, such as "Task · due Tue 28 Oct" or "Task · overdue 2 days".
    func detail(for note: Note) -> String {
        let kind = note.kind == .todoList ? "To-do list" : note.kind.rawValue.capitalized
        let repeatText = note.recurrence.map(RecurrenceParser.describe)
        return [kind, dueText(for: note), repeatText, note.siteHost ?? note.appName].compactMap { $0 }
            .joined(separator: " · ")
    }

    private func dueText(for note: Note) -> String? {
        guard let due = note.dueAt else { return nil }
        guard isOverdue(note) else { return "due " + dueDate(due, hasTime: note.dueHasTime) }
        let days =
            calendar.dateComponents([.day], from: calendar.startOfDay(for: due), to: calendar.startOfDay(for: now))
            .day ?? 0
        return days == 0 ? "overdue" : "overdue \(days) day\(days == 1 ? "" : "s")"
    }

    private func dueDate(_ due: Date, hasTime: Bool) -> String {
        let day = due.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        return hasTime ? day + " " + due.formatted(date: .omitted, time: .shortened) : day
    }
}
