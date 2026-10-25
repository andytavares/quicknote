import Foundation
import GRDB

/// Copies files into `AppPaths.attachments/<noteId>/` and keeps the `attachment` rows in step.
public struct AttachmentStore: Sendable {
    let paths: AppPaths
    let database: AppDatabase

    public init(paths: AppPaths, database: AppDatabase) {
        self.paths = paths
        self.database = database
    }

    public func attach(fileAt url: URL, to noteId: Int64, kind: AttachmentKind) throws -> Attachment {
        let fileName = url.lastPathComponent
        let relativePath = "\(noteId)/\(UUID().uuidString.prefix(8))-\(fileName)"
        let destination = paths.attachments.appending(path: relativePath)
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileManager.copyItem(at: url, to: destination)
        do {
            let byteCount = try fileManager.attributesOfItem(atPath: destination.path)[.size] as? Int ?? 0
            var attachment = Attachment(
                noteId: noteId, kind: kind,
                file: StoredFile(fileName: fileName, relativePath: relativePath, byteCount: byteCount))
            try database.writer.write { db in try attachment.insert(db) }
            return attachment
        } catch {
            try? fileManager.removeItem(at: destination)
            throw error
        }
    }

    public func fileURL(for attachment: Attachment) -> URL {
        paths.attachments.appending(path: attachment.relativePath)
    }

    public func setExtractedText(_ text: String, for attachmentId: Int64) throws {
        try database.writer.write { db in
            try db.execute(
                sql: "UPDATE attachment SET extractedText = ? WHERE id = ?", arguments: [text, attachmentId])
        }
    }

    public func remove(_ attachment: Attachment) throws {
        try? FileManager.default.removeItem(at: fileURL(for: attachment))
        try database.writer.write { db in _ = try attachment.delete(db) }
    }

    public func attachments(of noteId: Int64) throws -> [Attachment] {
        try database.writer.read { db in
            try Attachment.filter(Column("noteId") == noteId).order(Column("id")).fetchAll(db)
        }
    }
}
