import Foundation
import Testing

@testable import QuicknoteKit

struct NoteChangesTests {
    @Test func streamsTheCurrentNotesThenEveryChange() async throws {
        let database = try AppDatabase.inMemory()
        let repository = NoteRepository(database: database)
        var iterator = database.noteChanges().makeAsyncIterator()
        #expect(await iterator.next()?.isEmpty == true)

        var note = Note(body: "Buy milk")
        try repository.save(&note, now: Date())
        #expect(await iterator.next()?.map(\.title) == ["Buy milk"])

        try repository.delete(noteId: note.id!)
        #expect(await iterator.next()?.isEmpty == true)
    }
}
