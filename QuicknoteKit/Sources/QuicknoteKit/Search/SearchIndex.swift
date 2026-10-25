import Foundation
import GRDB

public struct NoteHit: Equatable, Sendable {
    public var note: Note
    public var snippet: String
}

public struct TranscriptHit: Equatable, Sendable {
    public var meetingId: Int64
    public var meetingTitle: String
    public var startMs: Int
    public var snippet: String
}

public struct FileHit: Equatable, Sendable {
    public var attachment: Attachment
    public var noteId: Int64
    public var snippet: String
}

public struct SearchResults: Equatable, Sendable {
    public var notes: [NoteHit] = []
    public var transcripts: [TranscriptHit] = []
    public var files: [FileHit] = []

    public var isEmpty: Bool { notes.isEmpty && transcripts.isEmpty && files.isEmpty }
}

/// Full-text search over notes, meeting transcripts, and attachment names and extracted text.
public struct SearchIndex: Sendable {
    /// Wrap each matched word in a snippet.
    public static let markStart = "«"
    public static let markEnd = "»"

    private let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    public func search(_ query: String, limitPerGroup: Int) throws -> SearchResults {
        guard let pattern = FTS5Pattern(matchingAllPrefixesIn: query) else { return SearchResults() }
        return try database.writer.read { db in
            SearchResults(
                notes: try Self.notes(db, pattern, limitPerGroup),
                transcripts: try Self.transcripts(db, pattern, limitPerGroup),
                files: try Self.files(db, pattern, limitPerGroup))
        }
    }

    private static func snippet(_ table: String, column: Int) -> String {
        "snippet(\(table), \(column), '\(markStart)', '\(markEnd)', '…', 12) AS snippet"
    }

    private static func notes(_ db: Database, _ pattern: FTS5Pattern, _ limit: Int) throws -> [NoteHit] {
        let sql = """
            SELECT note.*, \(snippet("note_ft", column: 0)) FROM note_ft
            JOIN note ON note.id = note_ft.rowid
            WHERE note_ft MATCH ?
            ORDER BY note.completedAt IS NOT NULL, bm25(note_ft) LIMIT ?
            """
        return try Row.fetchAll(db, sql: sql, arguments: [pattern, limit]).map {
            NoteHit(note: try Note(row: $0), snippet: $0["snippet"])
        }
    }

    private static func transcripts(_ db: Database, _ pattern: FTS5Pattern, _ limit: Int) throws -> [TranscriptHit] {
        let sql = """
            SELECT meeting.id AS meetingId, meeting.title AS meetingTitle, transcriptSegment.startMs AS startMs,
                \(snippet("transcriptSegment_ft", column: 0))
            FROM transcriptSegment_ft
            JOIN transcriptSegment ON transcriptSegment.id = transcriptSegment_ft.rowid
            JOIN meeting ON meeting.id = transcriptSegment.meetingId
            WHERE transcriptSegment_ft MATCH ?
            ORDER BY bm25(transcriptSegment_ft) LIMIT ?
            """
        return try Row.fetchAll(db, sql: sql, arguments: [pattern, limit]).map {
            TranscriptHit(
                meetingId: $0["meetingId"], meetingTitle: $0["meetingTitle"], startMs: $0["startMs"],
                snippet: $0["snippet"])
        }
    }

    private static func files(_ db: Database, _ pattern: FTS5Pattern, _ limit: Int) throws -> [FileHit] {
        let sql = """
            SELECT attachment.*, \(snippet("attachment_ft", column: -1)) FROM attachment_ft
            JOIN attachment ON attachment.id = attachment_ft.rowid
            WHERE attachment_ft MATCH ?
            ORDER BY bm25(attachment_ft) LIMIT ?
            """
        return try Row.fetchAll(db, sql: sql, arguments: [pattern, limit]).map {
            let attachment = try Attachment(row: $0)
            return FileHit(attachment: attachment, noteId: attachment.noteId, snippet: $0["snippet"])
        }
    }
}
