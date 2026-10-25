import QuicknoteKit

extension NoteKind {
    /// The name people see in menus, chips and lists.
    var title: String {
        switch self {
        case .note: "Note"
        case .todoList: "To-do list"
        case .task: "Task"
        case .reminder: "Reminder"
        case .event: "Event"
        case .idea: "Idea"
        case .bookmark: "Bookmark"
        case .bug: "Bug"
        case .context: "Where I stopped"
        }
    }
}
