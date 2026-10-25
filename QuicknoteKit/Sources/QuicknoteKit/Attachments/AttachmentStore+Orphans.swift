import Foundation
import GRDB

extension AttachmentStore {
    /// Deletes `Attachments/<noteId>` and `Attachments/meetings/<meetingId>` folders whose note or meeting is gone.
    /// Returns how many folders were removed.
    @discardableResult
    public func removeOrphanedFiles() throws -> Int {
        let (noteIds, meetingIds) = try database.writer.read { db in
            (
                Set(try Int64.fetchAll(db, sql: "SELECT id FROM note")),
                Set(try Int64.fetchAll(db, sql: "SELECT id FROM meeting"))
            )
        }
        let notes = try orphans(in: paths.attachments, keeping: noteIds)
        let meetings = try orphans(in: paths.attachments.appending(path: "meetings"), keeping: meetingIds)
        for folder in notes + meetings { try FileManager.default.removeItem(at: folder) }
        return notes.count + meetings.count
    }

    /// Numbered folders directly inside `parent` whose number is not in `liveIds`.
    private func orphans(in parent: URL, keeping liveIds: Set<Int64>) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: parent.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: parent, includingPropertiesForKeys: nil)
            .filter { folder in Int64(folder.lastPathComponent).map { !liveIds.contains($0) } ?? false }
    }
}
