import Foundation
import Testing

@testable import QuicknoteKit

struct AttachmentStoreTests {
    private func makeStore() throws -> (AttachmentStore, AppDatabase, TemporaryPaths, Int64) {
        let temporary = try TemporaryPaths()
        let database = try AppDatabase.inMemory()
        let noteId = try database.writer.write { db -> Int64 in
            var note = Note(body: "Boarding pass")
            try note.insert(db)
            return note.id!
        }
        return (AttachmentStore(paths: temporary.paths, database: database), database, temporary, noteId)
    }

    @Test func removingOrphansDeletesOnlyFoldersOfDeletedNotesAndMeetings() throws {
        let (store, database, temporary, liveNoteId) = try makeStore()
        defer { temporary.remove() }
        let liveMeetingId = try database.writer.write { db -> Int64 in
            var meeting = Meeting(noteId: liveNoteId, title: "Weekly sync")
            try meeting.insert(db)
            return meeting.id!
        }
        let folders = ["\(liveNoteId)", "999", "meetings/\(liveMeetingId)", "meetings/888"]
        for folder in folders {
            let url = temporary.paths.attachments.appending(path: folder)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try "audio".write(to: url.appending(path: "file"), atomically: true, encoding: .utf8)
        }

        #expect(try store.removeOrphanedFiles() == 2)

        let exists = folders.map {
            FileManager.default.fileExists(atPath: temporary.paths.attachments.appending(path: $0).path)
        }
        #expect(exists == [true, false, true, false])
    }

    @Test func attachCopiesFileUnderNoteFolderAndInsertsRow() throws {
        let (store, _, temporary, noteId) = try makeStore()
        defer { temporary.remove() }
        let source = try temporary.makeFile(named: "pass.pdf", contents: "12345")

        let attachment = try store.attach(fileAt: source, to: noteId, kind: .file)

        #expect(attachment.id != nil)
        #expect(attachment.fileName == "pass.pdf")
        #expect(attachment.byteCount == 5)
        #expect(attachment.relativePath.hasPrefix("\(noteId)/"))
        #expect(attachment.relativePath.hasSuffix("-pass.pdf"))
        #expect(try String(contentsOf: store.fileURL(for: attachment), encoding: .utf8) == "12345")
        #expect(try store.attachments(of: noteId).map(\.id) == [attachment.id])
    }

    @Test func sameNameAttachedTwiceKeepsBothFiles() throws {
        let (store, _, temporary, noteId) = try makeStore()
        defer { temporary.remove() }
        let source = try temporary.makeFile(named: "a.txt")

        let first = try store.attach(fileAt: source, to: noteId, kind: .file)
        let second = try store.attach(fileAt: source, to: noteId, kind: .file)

        #expect(first.relativePath != second.relativePath)
        #expect(try store.attachments(of: noteId).count == 2)
    }

    @Test func attachingMissingFileThrowsAndInsertsNothing() throws {
        let (store, _, temporary, noteId) = try makeStore()
        defer { temporary.remove() }
        let missing = temporary.scratch.appending(path: "nope.txt")

        #expect(throws: (any Error).self) { try store.attach(fileAt: missing, to: noteId, kind: .file) }
        #expect(try store.attachments(of: noteId).isEmpty)
    }

    @Test func removeDeletesFileAndRow() throws {
        let (store, _, temporary, noteId) = try makeStore()
        defer { temporary.remove() }
        let attachment = try store.attach(fileAt: try temporary.makeFile(named: "a.txt"), to: noteId, kind: .file)

        try store.remove(attachment)

        #expect(try store.attachments(of: noteId).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: store.fileURL(for: attachment).path))
    }

    @Test func setExtractedTextIsSavedOnTheRow() throws {
        let (store, _, temporary, noteId) = try makeStore()
        defer { temporary.remove() }
        let attachment = try store.attach(fileAt: try temporary.makeFile(named: "s.png"), to: noteId, kind: .image)

        try store.setExtractedText("Gate B12", for: attachment.id!)

        #expect(try store.attachments(of: noteId).first?.extractedText == "Gate B12")
    }
}
