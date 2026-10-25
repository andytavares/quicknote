import GRDB

/// How much is stored, shown in Settings › Data.
public struct LibraryCounts: Equatable, Sendable {
    public var notes: Int
    public var meetings: Int

    public init(notes: Int, meetings: Int) {
        self.notes = notes
        self.meetings = meetings
    }
}

extension AppDatabase {
    public func libraryCounts() throws -> LibraryCounts {
        try writer.read { db in
            LibraryCounts(notes: try Note.fetchCount(db), meetings: try Meeting.fetchCount(db))
        }
    }
}
