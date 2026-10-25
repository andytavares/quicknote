import Foundation
import GRDB
import Testing

@testable import QuicknoteKit

struct AppDatabaseTests {
    @Test func insertedNoteIsFoundByFullTextSearch() throws {
        let database = try AppDatabase.inMemory()
        try database.writer.write { db in
            var note = Note(body: "Call Jonah about the pricing page")
            try note.insert(db)
        }
        let hits = try database.writer.read { db in
            try Note.fetchAll(
                db,
                sql: "SELECT note.* FROM note JOIN note_ft ON note_ft.rowid = note.id AND note_ft MATCH ?",
                arguments: ["pricing"]
            )
        }
        #expect(hits.map(\.title) == ["Call Jonah about the pricing page"])
    }

    @Test func deletingANoteCascadesToItsAttachments() throws {
        let database = try AppDatabase.inMemory()
        let count = try database.writer.write { db in
            var note = Note(body: "Boarding pass")
            try note.insert(db)
            let file = StoredFile(fileName: "pass.pdf", relativePath: "1/pass.pdf", byteCount: 10)
            var attachment = Attachment(noteId: note.id!, kind: .file, file: file)
            try attachment.insert(db)
            _ = try note.delete(db)
            return try Attachment.fetchCount(db)
        }
        #expect(count == 0)
    }

    @Test func titleIsTheFirstNonEmptyLine() {
        #expect(Note(body: "\nLisbon trip\nflights booked").title == "Lisbon trip")
    }
}
