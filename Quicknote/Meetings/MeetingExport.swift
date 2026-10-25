import Foundation
import QuicknoteKit

/// The four things the detail window can export, and what each is called on disk.
enum MeetingExport: CaseIterable {
    case summary, transcript, notesAndTasks, audio

    var menuTitle: String {
        switch self {
        case .summary: "Summary (Markdown)"
        case .transcript: "Full transcript (.txt)"
        case .notesAndTasks: "Notes and tasks (Markdown)"
        case .audio: "Audio (.m4a)"
        }
    }

    var fileExtension: String {
        switch self {
        case .summary, .notesAndTasks: "md"
        case .transcript: "txt"
        case .audio: "m4a"
        }
    }

    func fileName(title: String, startedAt: Date) -> String {
        let cleaned = title.replacingOccurrences(of: "[/:\\\\]", with: "-", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        let day = startedAt.formatted(.iso8601.year().month().day())
        let suffix =
            switch self {
            case .summary: " summary"
            case .transcript: " transcript"
            case .notesAndTasks: " notes"
            case .audio: ""
            }
        return "\(cleaned.isEmpty ? "Meeting" : cleaned) \(day)\(suffix).\(fileExtension)"
    }

    /// The file's text, or nil for audio.
    func text(meeting: Meeting, transcript: MeetingTranscript) -> String? {
        switch self {
        case .summary:
            let day = meeting.startedAt.formatted(.iso8601.year().month().day())
            let summary = meeting.summary ?? ""
            return "# \(meeting.title)\n\n\(day) · \(MeetingTime.format(ms: meeting.durationMs))\n\n\(summary)\n"
        case .transcript: return TranscriptExporter.plainText(meeting: meeting, segments: transcript.segments)
        case .notesAndTasks: return TranscriptExporter.markdown(meeting: meeting, transcript: transcript)
        case .audio: return nil
        }
    }
}
