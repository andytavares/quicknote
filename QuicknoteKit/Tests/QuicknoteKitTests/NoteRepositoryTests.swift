import Foundation
import GRDB
import Testing

@testable import QuicknoteKit

struct NoteRepositoryTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)
    private let database: AppDatabase
    private let repository: NoteRepository

    init() throws {
        database = try AppDatabase.inMemory()
        repository = NoteRepository(database: database)
    }

    @discardableResult
    private func save(
        _ body: String, kind: NoteKind = .note, at offset: TimeInterval = 0,
        _ configure: (inout Note) -> Void = { _ in }
    ) throws -> Note {
        var note = Note(body: body, kind: kind, now: now)
        configure(&note)
        try repository.save(&note, now: now.addingTimeInterval(offset))
        return note
    }

    private func titles(_ filter: NoteListFilter) throws -> [String] {
        try repository.notes(matching: filter).map(\.title)
    }

    @Test func saveInsertsThenUpdatesAndStampsUpdatedAt() throws {
        var note = try save("first")
        #expect(note.id != nil)
        note.body = "second"
        try repository.save(&note, now: now.addingTimeInterval(50))
        let loaded = try #require(try repository.note(id: note.id!))
        #expect(loaded.body == "second")
        #expect(loaded.updatedAt == now.addingTimeInterval(50))
        #expect(try repository.notes(matching: .inbox).count == 1)
    }

    @Test func saveBuildsLinksCaseInsensitivelyAndSkipsUnknownTitles() throws {
        let target = try save("Pricing")
        let source = try save("see [[pricing]] and [[Nowhere]]")
        #expect(try repository.backlinks(to: target.id!).map(\.id) == [source.id])
    }

    @Test func resavingRebuildsLinks() throws {
        let target = try save("Pricing")
        var source = try save("[[Pricing]]")
        source.body = "no links now"
        try repository.save(&source, now: now)
        #expect(try repository.backlinks(to: target.id!).isEmpty)
    }

    @Test func noteCreatedAfterALinkToItGetsTheBacklink() throws {
        let source = try save("Plan: see [[Lisbon packing list]]")
        let target = try save("Lisbon packing list")
        #expect(try repository.backlinks(to: target.id!).map(\.id) == [source.id])
    }

    @Test func renamingANoteMovesItsBacklinks() throws {
        let oldLinker = try save("[[Pricing]]")
        let newLinker = try save("[[Pricing v3]]")
        var target = try save("Pricing")
        target.body = "Pricing v3"
        try repository.save(&target, now: now)
        let linkers = try repository.backlinks(to: target.id!).map(\.id)
        #expect(linkers == [newLinker.id])
        #expect(!linkers.contains(oldLinker.id))
    }

    @Test func noteDoesNotLinkToItself() throws {
        let note = try save("Loop [[Loop]]")
        #expect(try repository.backlinks(to: note.id!).isEmpty)
    }

    @Test func deleteRemovesNoteAndItsLinks() throws {
        let target = try save("Pricing")
        let source = try save("[[Pricing]]")
        try repository.delete(noteId: source.id!)
        #expect(try repository.note(id: source.id!) == nil)
        #expect(try repository.backlinks(to: target.id!).isEmpty)
    }

    @Test func inboxExcludesCompletedAndContextNotes() throws {
        try save("plain")
        try save("task", kind: .task)
        try save("ctx", kind: .context)
        try save("done") { $0.completedAt = now }
        #expect(Set(try titles(.inbox)) == ["plain", "task"])
    }

    @Test func kindProjectAndCompletedFilters() throws {
        var project = Project(name: "Site")
        try database.writer.write { try project.insert($0) }
        try save("bug one", kind: .bug) { $0.projectId = project.id }
        try save("bug two", kind: .bug) { $0.completedAt = now }
        try save("idea", kind: .idea)
        #expect(try titles(.kind(.bug)) == ["bug one"])
        #expect(try titles(.project(project.id!)) == ["bug one"])
        #expect(try titles(.completed) == ["bug two"])
    }

    @Test func ordersByDueDateNilLastThenNewest() throws {
        try save("old", at: 0)
        try save("new", at: 100)
        try save("due late") { $0.dueAt = now.addingTimeInterval(900) }
        try save("due soon") { $0.dueAt = now.addingTimeInterval(100) }
        #expect(try titles(.inbox) == ["due soon", "due late", "new", "old"])
    }

    @Test func linkSuggestionsPutPrefixMatchesBeforeContainsAndHonourLimit() throws {
        try save("My pricing")
        try save("Pricing page")
        try save("PRICING notes")
        try save("Roadmap")
        let all = try repository.linkSuggestions(prefix: "pric", limit: 10).map(\.title)
        #expect(Set(all.prefix(2)) == ["Pricing page", "PRICING notes"])
        #expect(all.last == "My pricing")
        #expect(try repository.linkSuggestions(prefix: "pric", limit: 1).count == 1)
    }

    @Test func linkSuggestionsTreatPercentLiterally() throws {
        try save("100% done")
        try save("anything")
        #expect(try repository.linkSuggestions(prefix: "%", limit: 10).map(\.title) == ["100% done"])
    }

    @Test func contextGroupsPreferSiteOverApp() throws {
        try save("a") {
            $0.siteHost = "github.com"
            $0.appBundleId = "com.apple.Safari"
            $0.appName = "Safari"
        }
        try save("b") { $0.siteHost = "github.com" }
        try save("c") {
            $0.appBundleId = "com.apple.dt.Xcode"
            $0.appName = "Xcode"
        }
        try save("unrelated")
        let groups = try repository.contextGroups()
        let site = try #require(groups.first { $0.siteHost == "github.com" })
        #expect(site.displayName == "github.com")
        #expect(Set(site.notes.map(\.title)) == ["a", "b"])
        let app = try #require(groups.first { $0.appBundleId == "com.apple.dt.Xcode" })
        #expect(app.displayName == "Xcode")
        #expect(app.siteHost == nil)
        #expect(groups.count == 2)
    }
}
