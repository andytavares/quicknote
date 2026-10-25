import Foundation
import GRDB

public struct ProjectRepository: Sendable {
    private let database: AppDatabase

    public init(database: AppDatabase) { self.database = database }

    public func create(name: String, color: String) throws -> Project {
        try database.writer.write { db in
            var project = Project(name: name, color: color)
            try project.insert(db)
            return project
        }
    }

    public func rename(projectId: Int64, to name: String) throws {
        try database.writer.write { db in
            try Project.filter(key: projectId).updateAll(db, Column("name").set(to: name))
        }
    }

    /// Notes in the project stay; the schema sets their `projectId` to nil.
    public func delete(projectId: Int64) throws {
        _ = try database.writer.write { try Project.deleteOne($0, key: projectId) }
    }

    public func all() throws -> [Project] {
        try database.writer.read {
            try Project.order(Column("name").collating(.localizedCaseInsensitiveCompare)).fetchAll($0)
        }
    }

    /// Note count per project id, zero for empty projects. Completed notes count too.
    public func noteCounts() throws -> [Int64: Int] {
        try database.writer.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT project.id, COUNT(note.id) FROM project
                    LEFT JOIN note ON note.projectId = project.id GROUP BY project.id
                    """)
            return Dictionary(uniqueKeysWithValues: rows.map { ($0[0] as Int64, $0[1] as Int) })
        }
    }
}
