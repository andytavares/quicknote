import Foundation
import QuicknoteKit

/// What Quicknote stores on this Mac, shown in Settings › Data.
struct DataSummary: Equatable {
    var noteCount: Int
    var meetingCount: Int
    var byteCount: Int64

    /// "412 notes · 9 meetings · 1.3 GB"
    var text: String {
        let notes = "\(noteCount) \(noteCount == 1 ? "note" : "notes")"
        let meetings = "\(meetingCount) \(meetingCount == 1 ? "meeting" : "meetings")"
        let size = ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
        return "\(notes) · \(meetings) · \(size)"
    }

    static func load(from environment: AppEnvironment) throws -> DataSummary {
        let counts = try environment.database.libraryCounts()
        return DataSummary(
            noteCount: counts.notes, meetingCount: counts.meetings, byteCount: folderSize(environment.paths.root))
    }

    static func folderSize(_ folder: URL) -> Int64 {
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey]
        let files = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: keys)
        return (files?.allObjects as? [URL] ?? []).reduce(0) { total, file in
            total + Int64((try? file.resourceValues(forKeys: Set(keys)).totalFileAllocatedSize) ?? 0)
        }
    }
}

/// The typed confirmation for Delete everything: only the exact word enables it.
enum DeleteConfirmation {
    static let word = "DELETE"

    static func isConfirmed(_ typed: String) -> Bool { typed == word }
}
