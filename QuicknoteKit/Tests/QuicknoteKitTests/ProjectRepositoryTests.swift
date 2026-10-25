import Foundation
import Testing

@testable import QuicknoteKit

struct ProjectRepositoryTests {
    private let database: AppDatabase
    private let projects: ProjectRepository

    init() throws {
        database = try AppDatabase.inMemory()
        projects = ProjectRepository(database: database)
    }

    @Test func createRenameAndList() throws {
        let created = try projects.create(name: "Website", color: "#112233")
        #expect(created.id != nil)
        try projects.rename(projectId: created.id!, to: "Site")
        #expect(try projects.all().map(\.name) == ["Site"])
        #expect(try projects.all().first?.color == "#112233")
    }

    @Test func deletingKeepsNotesWithoutProject() throws {
        let project = try projects.create(name: "Website", color: "#112233")
        let notes = NoteRepository(database: database)
        var note = Note(body: "keep me")
        note.projectId = project.id
        try notes.save(&note, now: Date())
        try projects.delete(projectId: project.id!)
        #expect(try projects.all().isEmpty)
        #expect(try notes.note(id: note.id!)?.projectId == nil)
    }

    @Test func noteCountsIncludeEmptyProjects() throws {
        let busy = try projects.create(name: "Busy", color: "#111111")
        let empty = try projects.create(name: "Empty", color: "#222222")
        let notes = NoteRepository(database: database)
        for body in ["one", "two"] {
            var note = Note(body: body)
            note.projectId = busy.id
            try notes.save(&note, now: Date())
        }
        let counts = try projects.noteCounts()
        #expect(counts[busy.id!] == 2)
        #expect(counts[empty.id!] == 0)
    }
}
