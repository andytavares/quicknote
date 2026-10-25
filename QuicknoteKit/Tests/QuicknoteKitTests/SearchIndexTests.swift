import Foundation
import GRDB
import Testing

@testable import QuicknoteKit

struct SearchIndexTests {
    @discardableResult
    private func addNote(_ database: AppDatabase, _ body: String, completed: Bool = false) throws -> Int64 {
        try database.writer.write { db in
            var note = Note(body: body)
            if completed { note.completedAt = Date() }
            try note.insert(db)
            return note.id!
        }
    }

    @Test func notesMatchPrefixesAndSnippetMarksTheHit() throws {
        let database = try AppDatabase.inMemory()
        try addNote(database, "Call Jonah about the pricing page")
        try addNote(database, "Buy milk")

        let results = try SearchIndex(database: database).search("pric", limitPerGroup: 5)

        #expect(results.notes.count == 1)
        #expect(results.notes[0].snippet.contains("\(SearchIndex.markStart)pricing\(SearchIndex.markEnd)"))
    }

    @Test func allWordsMustMatch() throws {
        let database = try AppDatabase.inMemory()
        try addNote(database, "pricing page")
        try addNote(database, "pricing only")

        let results = try SearchIndex(database: database).search("pricing page", limitPerGroup: 5)

        #expect(results.notes.count == 1)
    }

    @Test func openNotesComeBeforeCompletedOnes() throws {
        let database = try AppDatabase.inMemory()
        try addNote(database, "pricing pricing pricing", completed: true)
        try addNote(database, "a long open note that mentions pricing once among many other words here")

        let notes = try SearchIndex(database: database).search("pricing", limitPerGroup: 5).notes

        #expect(notes.map { $0.note.completedAt == nil } == [true, false])
    }

    @Test func limitAppliesPerGroup() throws {
        let database = try AppDatabase.inMemory()
        for index in 0..<5 { try addNote(database, "pricing \(index)") }

        #expect(try SearchIndex(database: database).search("pricing", limitPerGroup: 2).notes.count == 2)
    }

    @Test func emptyAndPunctuationQueriesReturnNothingWithoutThrowing() throws {
        let database = try AppDatabase.inMemory()
        try addNote(database, "pricing")
        let index = SearchIndex(database: database)

        for query in ["", "   ", "\"", "*", "(", "AND", "- + ^"] {
            #expect(try index.search(query, limitPerGroup: 5).notes.isEmpty, "query \(query)")
        }
    }

    @Test func transcriptHitsCarryMeetingTitleAndStartTime() throws {
        let database = try AppDatabase.inMemory()
        let noteId = try addNote(database, "Standup")
        try database.writer.write { db in
            var meeting = Meeting(noteId: noteId, title: "Weekly sync")
            try meeting.insert(db)
            let line = SpokenLine(span: 4000..<6000, speaker: .others, text: "we should revisit the roadmap")
            var segment = TranscriptSegment(meetingId: meeting.id!, line: line)
            try segment.insert(db)
        }

        let hits = try SearchIndex(database: database).search("roadmap", limitPerGroup: 5).transcripts

        #expect(hits.count == 1)
        #expect(hits[0].meetingTitle == "Weekly sync")
        #expect(hits[0].startMs == 4000)
        #expect(hits[0].snippet.contains("\(SearchIndex.markStart)roadmap\(SearchIndex.markEnd)"))
    }

    @Test func fileHitsMatchNameAndExtractedText() throws {
        let database = try AppDatabase.inMemory()
        let noteId = try addNote(database, "Trip")
        try database.writer.write { db in
            let file = StoredFile(fileName: "boarding.png", relativePath: "1/x-boarding.png", byteCount: 1)
            var attachment = Attachment(noteId: noteId, kind: .image, file: file)
            attachment.extractedText = "Gate B12 departs 09:40"
            try attachment.insert(db)
        }
        let index = SearchIndex(database: database)

        let byText = try index.search("departs", limitPerGroup: 5).files
        let byName = try index.search("boarding", limitPerGroup: 5).files

        #expect(byText.map(\.noteId) == [noteId])
        #expect(byText[0].attachment.fileName == "boarding.png")
        #expect(byName.count == 1)
    }

    @Test func deletedNotesLeaveTheIndex() throws {
        let database = try AppDatabase.inMemory()
        let noteId = try addNote(database, "pricing")
        _ = try database.writer.write { db in try Note.deleteOne(db, id: noteId) }

        #expect(try SearchIndex(database: database).search("pricing", limitPerGroup: 5).notes.isEmpty)
    }
}
