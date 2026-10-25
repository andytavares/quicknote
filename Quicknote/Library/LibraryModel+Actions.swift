import Foundation
import QuicknoteKit

enum ProjectEdit: Identifiable {
    case create
    case rename(Project)

    var id: String {
        switch self {
        case .create: "create"
        case .rename(let project): "rename-\(project.id ?? 0)"
        }
    }
}

extension LibraryModel {
    private static let projectColors = ["#2F6FED", "#E5484D", "#30A46C", "#F5A524", "#8E4EC6"]

    /// Shows a note in the section of its type with only that note selected.
    func open(_ note: Note) {
        guard let noteId = note.id else { return }
        section = LibrarySection.containing(note)
        selection = [noteId]
    }

    func open(noteId: Int64) {
        guard let note = try? notes.note(id: noteId) else { return }
        open(note)
    }

    /// Checks a note off (a repeating one moves to its next date) or reopens a completed one.
    func toggleCompletion(of note: Note) {
        var updated = note
        if note.completedAt != nil {
            updated.completedAt = nil
        } else {
            updated = note.completing(now: Date(), calendar: .current)
        }
        try? notes.save(&updated, now: Date())
        reload()
    }

    func confirmDeletion() {
        for noteId in pendingDeletion { try? notes.delete(noteId: noteId) }
        selection.subtract(pendingDeletion)
        pendingDeletion = []
        reload()
    }

    func createProject(named name: String) {
        let color = Self.projectColors[projects.count % Self.projectColors.count]
        guard let project = try? projectRepository.create(name: name, color: color), let projectId = project.id else {
            return
        }
        reload()
        section = .project(projectId)
    }

    func rename(_ project: Project, to name: String) {
        guard let projectId = project.id else { return }
        try? projectRepository.rename(projectId: projectId, to: name)
        reload()
    }

    func delete(_ project: Project) {
        guard let projectId = project.id else { return }
        try? projectRepository.delete(projectId: projectId)
        if section == .project(projectId) { section = .inbox }
        reload()
    }
}
