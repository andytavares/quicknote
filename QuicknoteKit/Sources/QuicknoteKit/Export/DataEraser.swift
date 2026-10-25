import Foundation
import GRDB

/// "Delete everything": every row and every attachment file. The database stays usable.
public struct DataEraser: Sendable {
    private let paths: AppPaths
    private let database: AppDatabase

    public init(paths: AppPaths, database: AppDatabase) {
        self.paths = paths
        self.database = database
    }

    public func eraseEverything() throws {
        try database.writer.write { db in
            for table in try Self.contentTables(db) {
                try db.execute(sql: "DELETE FROM \(table.quotedDatabaseIdentifier)")
            }
        }
        let fileManager = FileManager.default
        let entries =
            (try? fileManager.contentsOfDirectory(at: paths.attachments, includingPropertiesForKeys: nil)) ?? []
        for entry in entries { try fileManager.removeItem(at: entry) }
        try paths.createDirectories()
    }

    /// Search indexes follow their tables through triggers, so only content tables are listed.
    private static func contentTables(_ db: Database) throws -> [String] {
        try String.fetchAll(
            db,
            sql: """
                SELECT name FROM sqlite_master
                WHERE type = 'table' AND name NOT LIKE 'sqlite\\_%' ESCAPE '\\'
                AND name NOT LIKE '%\\_ft%' ESCAPE '\\' AND name != 'grdb_migrations'
                """)
    }
}
