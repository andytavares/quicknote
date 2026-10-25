import Foundation
import GRDB

/// The one SQLite database. Every feature reads and writes through `writer`.
public final class AppDatabase: Sendable {
    public let writer: any DatabaseWriter

    public init(_ writer: any DatabaseWriter) throws {
        self.writer = writer
        try Self.migrator.migrate(writer)
    }

    /// The on-disk database in `AppPaths.root`.
    public static func onDisk(paths: AppPaths = .live) throws -> AppDatabase {
        try paths.createDirectories()
        return try AppDatabase(DatabasePool(path: paths.database.path))
    }

    /// An empty database for tests and previews.
    public static func inMemory() throws -> AppDatabase {
        try AppDatabase(DatabaseQueue())
    }

    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try Schema.createProjects(db)
            try Schema.createNotes(db)
            try Schema.createAttachmentsAndLinks(db)
            try Schema.createMeetings(db)
            try Schema.createSearchIndexes(db)
        }
        return migrator
    }
}

/// Version 1 of the schema. Later versions add new migrations; never edit these.
enum Schema {
    static func createProjects(_ db: Database) throws {
        try db.create(table: "project") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("name", .text).notNull()
            t.column("color", .text).notNull()
        }
    }

    static func createNotes(_ db: Database) throws {
        try db.create(table: "note") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("body", .text).notNull()
            t.column("kind", .text).notNull().indexed()
            t.column("color", .text).notNull()
            t.column("font", .text).notNull()
            t.belongsTo("project", onDelete: .setNull)
            t.column("dueAt", .datetime).indexed()
            t.column("dueHasTime", .boolean).notNull()
            t.column("priority", .integer).notNull()
            t.column("recurrenceJSON", .text)
            t.column("snoozedUntil", .datetime)
            t.column("appBundleId", .text).indexed()
            t.column("appName", .text)
            t.column("siteHost", .text).indexed()
            t.column("url", .text)
            t.column("pinnedToContext", .boolean).notNull()
            t.column("onEdge", .boolean).notNull()
            t.column("calendarEventId", .text)
            t.column("canvasJSON", .text)
            t.column("sourceMeetingId", .integer)
            t.column("sourceMs", .integer)
            t.column("completedAt", .datetime)
            t.column("createdAt", .datetime).notNull()
            t.column("updatedAt", .datetime).notNull()
        }
    }

    static func createAttachmentsAndLinks(_ db: Database) throws {
        try db.create(table: "attachment") { t in
            t.autoIncrementedPrimaryKey("id")
            t.belongsTo("note", onDelete: .cascade).notNull()
            t.column("kind", .text).notNull()
            t.column("fileName", .text).notNull()
            t.column("relativePath", .text).notNull()
            t.column("byteCount", .integer).notNull()
            t.column("extractedText", .text)
            t.column("createdAt", .datetime).notNull()
        }
        try db.create(table: "noteLink") { t in
            t.belongsTo("fromNote", inTable: "note", onDelete: .cascade).notNull()
            t.belongsTo("toNote", inTable: "note", onDelete: .cascade).notNull()
            t.primaryKey(["fromNoteId", "toNoteId"])
        }
    }

    static func createMeetings(_ db: Database) throws {
        try db.create(table: "meeting") { t in
            t.autoIncrementedPrimaryKey("id")
            t.belongsTo("note", onDelete: .cascade).notNull()
            t.column("title", .text).notNull()
            t.column("audioPath", .text)
            t.column("startedAt", .datetime).notNull()
            t.column("durationMs", .integer).notNull()
            t.column("summary", .text)
        }
        try db.create(table: "transcriptSegment") { t in
            t.autoIncrementedPrimaryKey("id")
            t.belongsTo("meeting", onDelete: .cascade).notNull()
            t.column("startMs", .integer).notNull()
            t.column("endMs", .integer).notNull()
            t.column("speaker", .text).notNull()
            t.column("text", .text).notNull()
        }
        try db.create(table: "meetingBookmark") { t in
            t.autoIncrementedPrimaryKey("id")
            t.belongsTo("meeting", onDelete: .cascade).notNull()
            t.column("atMs", .integer).notNull()
            t.column("label", .text)
        }
    }

    static func createSearchIndexes(_ db: Database) throws {
        let indexed = [
            ("note", ["body"]), ("transcriptSegment", ["text"]), ("attachment", ["fileName", "extractedText"]),
        ]
        for (table, columns) in indexed {
            try db.create(virtualTable: "\(table)_ft", using: FTS5()) { t in
                t.synchronize(withTable: table)
                t.tokenizer = .porter(wrapping: .unicode61())
                for column in columns { t.column(column) }
            }
        }
    }
}
