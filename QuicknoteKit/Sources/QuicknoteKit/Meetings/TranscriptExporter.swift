import Foundation

/// Everything a meeting export lists besides the meeting row itself.
public struct MeetingTranscript: Sendable {
    public var segments: [TranscriptSegment]
    public var bookmarks: [MeetingBookmark]
    public var actionItems: [ActionItem]

    public init(segments: [TranscriptSegment], bookmarks: [MeetingBookmark], actionItems: [ActionItem]) {
        self.segments = segments
        self.bookmarks = bookmarks
        self.actionItems = actionItems
    }
}

public enum TranscriptExporter {
    /// One `[mm:ss] Speaker: text` line per segment.
    public static func plainText(meeting: Meeting, segments: [TranscriptSegment]) -> String {
        segments.map(line).joined(separator: "\n")
    }

    public static func markdown(meeting: Meeting, transcript: MeetingTranscript) -> String {
        let date = meeting.startedAt.formatted(.iso8601.year().month().day())
        var sections = ["# \(meeting.title)", "\(date) · \(MeetingTime.format(ms: meeting.durationMs))"]
        if let summary = meeting.summary, !summary.isEmpty { sections.append("## Summary\n\n\(summary)") }
        if !transcript.bookmarks.isEmpty {
            let lines = transcript.bookmarks.map { "- [\(MeetingTime.format(ms: $0.atMs))] \($0.label ?? "Bookmark")" }
            sections.append("## Bookmarks\n\n" + lines.joined(separator: "\n"))
        }
        if !transcript.actionItems.isEmpty {
            let lines = transcript.actionItems.map { "- [ ] \($0.text) ([\(MeetingTime.format(ms: $0.atMs))])" }
            sections.append("## Action items\n\n" + lines.joined(separator: "\n"))
        }
        sections.append("## Transcript\n\n" + plainText(meeting: meeting, segments: transcript.segments))
        return sections.joined(separator: "\n\n")
    }

    private static func line(_ segment: TranscriptSegment) -> String {
        let speaker = segment.speaker == .me ? "Me" : "Others"
        return "[\(MeetingTime.format(ms: segment.startMs))] \(speaker): \(segment.text)"
    }
}
