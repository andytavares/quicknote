import Foundation
import QuicknoteKit

nonisolated enum SearchGroup: String, CaseIterable {
    case notes = "Notes"
    case transcripts = "Meeting transcripts"
    case files = "Files and Snaps"
}

nonisolated enum SearchOpenAction: Equatable {
    case note(id: Int64)
    case meeting(id: Int64, atMs: Int)
}

/// One result line, whichever group it came from.
nonisolated enum SearchRow: Equatable, Identifiable {
    case note(NoteHit)
    case transcript(TranscriptHit)
    case file(FileHit)

    var id: String {
        switch self {
        case .note(let hit): "note-\(hit.note.id ?? 0)"
        case .transcript(let hit): "transcript-\(hit.meetingId)-\(hit.startMs)"
        case .file(let hit): "file-\(hit.attachment.id ?? 0)"
        }
    }

    var group: SearchGroup {
        switch self {
        case .note: .notes
        case .transcript: .transcripts
        case .file: .files
        }
    }

    var snippet: String {
        switch self {
        case .note(let hit): hit.snippet
        case .transcript(let hit): hit.snippet
        case .file(let hit): hit.snippet
        }
    }

    var openAction: SearchOpenAction {
        switch self {
        case .note(let hit): .note(id: hit.note.id ?? 0)
        case .transcript(let hit): .meeting(id: hit.meetingId, atMs: hit.startMs)
        case .file(let hit): .note(id: hit.noteId)
        }
    }

    /// "mm:ss" for transcript rows, nil otherwise.
    var timestamp: String? {
        guard case .transcript(let hit) = self else { return nil }
        let seconds = hit.startMs / 1000
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    var detail: String {
        switch self {
        case .note(let hit): hit.note.kind.rawValue.capitalized
        case .transcript(let hit): hit.meetingTitle
        case .file(let hit): hit.attachment.fileName
        }
    }

    var accessibilityLabel: String {
        let when = timestamp.map { " at \($0)" } ?? ""
        return "\(group.rawValue): \(SearchSnippet.plainText(snippet)), \(detail)\(when)"
    }
}

nonisolated extension SearchResults {
    /// Rows in display order: notes, transcripts, files. Empty groups add nothing.
    var rows: [SearchRow] {
        notes.map(SearchRow.note) + transcripts.map(SearchRow.transcript) + files.map(SearchRow.file)
    }
}
