import Foundation
import GRDB

/// What a note is. Changing it from the Type menu keeps the body.
public enum NoteKind: String, Codable, CaseIterable, Sendable, DatabaseValueConvertible {
    case note, todoList, task, reminder, event, idea, bookmark, bug, context
}

/// Every capture is a note. Optional fields are set after `init` as the feature needs them.
public struct Note: Codable, Equatable, Identifiable, Sendable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "note"

    public var id: Int64?
    public var body: String
    public var kind: NoteKind
    /// Hex colour such as "#FBE38E".
    public var color = "#FBE38E"
    public var font = "system"
    public var projectId: Int64?
    public var dueAt: Date?
    public var dueHasTime = false
    /// 0 none, 1 low, 2 medium, 3 high.
    public var priority = 0
    /// JSON-encoded `RecurrenceRule`.
    public var recurrenceJSON: String?
    public var snoozedUntil: Date?
    public var appBundleId: String?
    public var appName: String?
    public var siteHost: String?
    public var url: String?
    /// When true the note shows on the edge only while its app or site is in front.
    public var pinnedToContext = false
    /// When true the note waits as a tab on the screen edge.
    public var onEdge = true
    public var calendarEventId: String?
    /// JSON-encoded `CanvasDocument` for Snaps and Cards.
    public var canvasJSON: String?
    public var sourceMeetingId: Int64?
    public var sourceMs: Int?
    public var completedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date

    public init(body: String, kind: NoteKind = .note, now: Date = Date()) {
        self.body = body
        self.kind = kind
        self.createdAt = now
        self.updatedAt = now
    }

    /// First non-empty line, used as the title everywhere.
    public var title: String {
        body.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}

public struct Project: Codable, Equatable, Identifiable, Sendable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "project"
    public var id: Int64?
    public var name: String
    public var color: String

    public init(name: String, color: String = "#2F6FED") {
        self.name = name
        self.color = color
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}

public enum AttachmentKind: String, Codable, Sendable, DatabaseValueConvertible {
    case image, audio, file, snap
}

/// A file copied into `AppPaths.attachments`.
public struct StoredFile: Codable, Equatable, Sendable {
    public var fileName: String
    /// Path relative to `AppPaths.attachments`.
    public var relativePath: String
    public var byteCount: Int

    public init(fileName: String, relativePath: String, byteCount: Int) {
        self.fileName = fileName
        self.relativePath = relativePath
        self.byteCount = byteCount
    }
}

public struct Attachment: Codable, Equatable, Identifiable, Sendable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "attachment"
    public var id: Int64?
    public var noteId: Int64
    public var kind: AttachmentKind
    public var fileName: String
    public var relativePath: String
    public var byteCount: Int
    /// Text read from the file (OCR for images), searchable.
    public var extractedText: String?
    public var createdAt = Date()

    public init(noteId: Int64, kind: AttachmentKind, file: StoredFile) {
        self.noteId = noteId
        self.kind = kind
        self.fileName = file.fileName
        self.relativePath = file.relativePath
        self.byteCount = file.byteCount
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}

public struct NoteLink: Codable, Equatable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "noteLink"
    public var fromNoteId: Int64
    public var toNoteId: Int64

    public init(fromNoteId: Int64, toNoteId: Int64) {
        self.fromNoteId = fromNoteId
        self.toNoteId = toNoteId
    }
}

public struct Meeting: Codable, Equatable, Identifiable, Sendable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "meeting"
    public var id: Int64?
    public var noteId: Int64
    public var title: String
    /// Path relative to `AppPaths.attachments`.
    public var audioPath: String?
    public var startedAt: Date
    public var durationMs = 0
    public var summary: String?

    public init(noteId: Int64, title: String, startedAt: Date = Date()) {
        self.noteId = noteId
        self.title = title
        self.startedAt = startedAt
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}

public enum Speaker: String, Codable, Sendable, DatabaseValueConvertible {
    /// Microphone input.
    case me
    /// Mac audio input (the other people on a call).
    case others
}

/// One finished stretch of speech, as the transcriber produces it.
public struct SpokenLine: Codable, Equatable, Sendable {
    /// Milliseconds from the start of the recording.
    public var span: Range<Int>
    public var speaker: Speaker
    public var text: String

    public init(span: Range<Int>, speaker: Speaker, text: String) {
        self.span = span
        self.speaker = speaker
        self.text = text
    }
}

public struct TranscriptSegment: Codable, Equatable, Identifiable, Sendable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "transcriptSegment"
    public var id: Int64?
    public var meetingId: Int64
    public var startMs: Int
    public var endMs: Int
    public var speaker: Speaker
    public var text: String

    public init(meetingId: Int64, line: SpokenLine) {
        self.meetingId = meetingId
        self.startMs = line.span.lowerBound
        self.endMs = line.span.upperBound
        self.speaker = line.speaker
        self.text = line.text
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}

public struct MeetingBookmark: Codable, Equatable, Identifiable, Sendable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "meetingBookmark"
    public var id: Int64?
    public var meetingId: Int64
    public var atMs: Int
    public var label: String?

    public init(meetingId: Int64, atMs: Int, label: String? = nil) {
        self.meetingId = meetingId
        self.atMs = atMs
        self.label = label
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}
