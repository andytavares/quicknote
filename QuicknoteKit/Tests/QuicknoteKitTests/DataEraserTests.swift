import Foundation
import GRDB
import Testing

@testable import QuicknoteKit

struct DataEraserTests {
    @Test func eraseEverythingEmptiesTablesIndexesAndAttachmentFiles() throws {
        let temporary = try TemporaryPaths()
        defer { temporary.remove() }
        let database = try AppDatabase.inMemory()
        let noteId = try database.writer.write { db -> Int64 in
            var project = Project(name: "Home")
            try project.insert(db)
            var note = Note(body: "pricing page")
            note.projectId = project.id
            try note.insert(db)
            var meeting = Meeting(noteId: note.id!, title: "Sync")
            try meeting.insert(db)
            var segment = TranscriptSegment(
                meetingId: meeting.id!, line: SpokenLine(span: 0..<10, speaker: .me, text: "roadmap"))
            try segment.insert(db)
            _ = try MeetingBookmark(meetingId: meeting.id!, atMs: 1).inserted(db)
            return note.id!
        }
        _ = try AttachmentStore(paths: temporary.paths, database: database)
            .attach(fileAt: try temporary.makeFile(named: "a.txt"), to: noteId, kind: .file)

        try DataEraser(paths: temporary.paths, database: database).eraseEverything()

        let counts = try database.writer.read { db in
            try ["project", "note", "attachment", "noteLink", "meeting", "transcriptSegment", "meetingBookmark"]
                .map { try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \($0)")! }
        }
        #expect(counts == [0, 0, 0, 0, 0, 0, 0])
        let index = SearchIndex(database: database)
        #expect(try index.search("pricing", limitPerGroup: 5).notes.isEmpty)
        #expect(try index.search("roadmap", limitPerGroup: 5).transcripts.isEmpty)
        #expect(try index.search("a", limitPerGroup: 5).files.isEmpty)
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: temporary.paths.attachments.path)
        #expect(leftovers.isEmpty)
    }

    @Test func databaseStillWorksAfterErasing() throws {
        let temporary = try TemporaryPaths()
        defer { temporary.remove() }
        let database = try AppDatabase.inMemory()
        try database.writer.write { db in
            var note = Note(body: "old"); try note.insert(db)
        }

        try DataEraser(paths: temporary.paths, database: database).eraseEverything()
        try database.writer.write { db in
            var note = Note(body: "fresh pricing"); try note.insert(db)
        }

        let hits = try SearchIndex(database: database).search("pricing", limitPerGroup: 5).notes
        #expect(hits.map(\.note.title) == ["fresh pricing"])
        #expect(FileManager.default.fileExists(atPath: temporary.paths.attachments.path))
    }
}
