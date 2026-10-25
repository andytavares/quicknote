import Foundation
import QuicknoteKit

enum TaskGrouping: String, CaseIterable, Identifiable {
    case dueDate = "By due date"
    case project = "By project"
    case priority = "By priority"

    var id: String { rawValue }
}

struct TaskGroup: Equatable, Identifiable {
    /// Empty for a flat list.
    let title: String
    let notes: [Note]

    var id: String { title }
}

/// Splits notes into the groups of the Tasks view. Empty groups are left out and notes keep their incoming order.
struct TaskGrouper {
    let now: Date
    let calendar: Calendar
    let projects: [Project]

    func groups(_ notes: [Note], by grouping: TaskGrouping) -> [TaskGroup] {
        switch grouping {
        case .dueDate: ordered(notes, titles: ["Overdue", "Today", "This week", "Later", "No date"], by: dueTitle)
        case .project: byProject(notes)
        case .priority: ordered(notes, titles: ["High", "Medium", "Low", "No priority"], by: priorityTitle)
        }
    }

    func flat(_ notes: [Note]) -> [TaskGroup] {
        notes.isEmpty ? [] : [TaskGroup(title: "", notes: notes)]
    }

    /// A date without a time is overdue only after its day has passed.
    func isOverdue(_ note: Note) -> Bool {
        guard let due = note.dueAt, note.completedAt == nil else { return false }
        return due < (note.dueHasTime ? now : calendar.startOfDay(for: now))
    }

    private func dueTitle(_ note: Note) -> String {
        guard let due = note.dueAt else { return "No date" }
        if isOverdue(note) { return "Overdue" }
        if calendar.isDate(due, inSameDayAs: now) { return "Today" }
        let week = calendar.dateInterval(of: .weekOfYear, for: now)
        return week.map { due < $0.end } == true ? "This week" : "Later"
    }

    private func priorityTitle(_ note: Note) -> String {
        switch note.priority {
        case 3...: "High"
        case 2: "Medium"
        case 1: "Low"
        default: "No priority"
        }
    }

    private func ordered(_ notes: [Note], titles: [String], by title: (Note) -> String) -> [TaskGroup] {
        let byTitle = Dictionary(grouping: notes, by: title)
        return titles.compactMap { title in byTitle[title].map { TaskGroup(title: title, notes: $0) } }
    }

    private func byProject(_ notes: [Note]) -> [TaskGroup] {
        let byProjectId = Dictionary(grouping: notes) { $0.projectId }
        let named = projects.compactMap { project in
            byProjectId[project.id].map { TaskGroup(title: project.name, notes: $0) }
        }
        return named + (byProjectId[nil].map { [TaskGroup(title: "No project", notes: $0)] } ?? [])
    }
}
