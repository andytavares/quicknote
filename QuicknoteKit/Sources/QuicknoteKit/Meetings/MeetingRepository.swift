import Foundation
import GRDB

/// What the recorder hands over when a meeting ends.
public struct FinishedRecording: Sendable {
    public var durationMs: Int
    public var audioPath: String

    public init(durationMs: Int, audioPath: String) {
        self.durationMs = durationMs
        self.audioPath = audioPath
    }
}

public struct MeetingRepository: Sendable {
    private let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    public func start(title: String, at date: Date) throws -> Meeting {
        try database.writer.write { db in
            var note = Note(body: title, kind: .note, now: date)
            note.onEdge = false
            try note.insert(db)
            var meeting = Meeting(noteId: note.id!, title: title, startedAt: date)
            try meeting.insert(db)
            return meeting
        }
    }

    public func append(_ lines: [SpokenLine], to meetingId: Int64) throws {
        try database.writer.write { db in
            for line in lines {
                var segment = TranscriptSegment(meetingId: meetingId, line: line)
                try segment.insert(db)
            }
        }
    }

    public func addBookmark(at ms: Int, to meetingId: Int64) throws -> MeetingBookmark {
        try database.writer.write { db in
            var bookmark = MeetingBookmark(meetingId: meetingId, atMs: ms)
            try bookmark.insert(db)
            return bookmark
        }
    }

    public func label(bookmarkId: Int64, as label: String) throws {
        try database.writer.write { db in
            try db.execute(sql: "UPDATE meetingBookmark SET label = ? WHERE id = ?", arguments: [label, bookmarkId])
        }
    }

    /// Stores the recording and saves each action item as a task. Safe to call again: tasks are made once.
    public func finish(meetingId: Int64, recording: FinishedRecording) throws -> [Note] {
        try database.writer.write { db in
            try db.execute(
                sql: "UPDATE meeting SET durationMs = ?, audioPath = ? WHERE id = ?",
                arguments: [recording.durationMs, recording.audioPath, meetingId])
            let existing = try Self.tasks(of: meetingId, in: db)
            guard existing.isEmpty else { return existing }
            let now = Date()
            let segments = try Self.segments(of: meetingId, in: db)
            for item in ActionItemExtractor.actionItems(in: segments, now: now) {
                var task = Note(body: item.text, kind: .task, now: now)
                task.dueAt = item.due
                task.sourceMeetingId = meetingId
                task.sourceMs = item.atMs
                try task.insert(db)
            }
            return try Self.tasks(of: meetingId, in: db)
        }
    }

    public func setSummary(_ summary: String, for meetingId: Int64) throws {
        try database.writer.write { db in
            try db.execute(sql: "UPDATE meeting SET summary = ? WHERE id = ?", arguments: [summary, meetingId])
        }
    }

    public func meeting(id: Int64) throws -> Meeting? {
        try database.writer.read { try Meeting.fetchOne($0, key: id) }
    }

    public func segments(of meetingId: Int64) throws -> [TranscriptSegment] {
        try database.writer.read { try Self.segments(of: meetingId, in: $0) }
    }

    public func bookmarks(of meetingId: Int64) throws -> [MeetingBookmark] {
        try database.writer.read { db in
            try MeetingBookmark.filter(Column("meetingId") == meetingId).order(Column("atMs")).fetchAll(db)
        }
    }

    public func actionItemTasks(of meetingId: Int64) throws -> [Note] {
        try database.writer.read { try Self.tasks(of: meetingId, in: $0) }
    }

    /// Newest first.
    public func all() throws -> [Meeting] {
        try database.writer.read { try Meeting.order(Column("startedAt").desc, Column("id").desc).fetchAll($0) }
    }

    private static func segments(of meetingId: Int64, in db: Database) throws -> [TranscriptSegment] {
        try TranscriptSegment.filter(Column("meetingId") == meetingId).order(Column("startMs"), Column("id")).fetchAll(
            db)
    }

    private static func tasks(of meetingId: Int64, in db: Database) throws -> [Note] {
        try Note.filter(Column("sourceMeetingId") == meetingId && Column("kind") == NoteKind.task)
            .order(Column("sourceMs"), Column("id")).fetchAll(db)
    }
}
