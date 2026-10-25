import Foundation
import Testing

@testable import QuicknoteKit

struct TranscriptExporterTests {
    let meeting = Meeting(
        noteId: 1, title: "Design sync",
        startedAt: Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 9))!)
    let segments = [
        TranscriptSegment(
            meetingId: 1, line: SpokenLine(span: 1_112_000..<1_118_000, speaker: .others, text: "Ship it.")),
        TranscriptSegment(meetingId: 1, line: SpokenLine(span: 3_725_000..<3_730_000, speaker: .me, text: "Agreed.")),
    ]

    @Test func plainTextLabelsSpeakersAndTimes() {
        let text = TranscriptExporter.plainText(meeting: meeting, segments: segments)
        #expect(text == "[18:32] Others: Ship it.\n[1:02:05] Me: Agreed.")
    }

    @Test func markdownHasEverySection() {
        var finished = meeting
        finished.durationMs = 3_725_000
        finished.summary = "Agreed to ship."
        let transcript = MeetingTranscript(
            segments: segments,
            bookmarks: [MeetingBookmark(meetingId: 1, atMs: 61_000, label: "Pricing")],
            actionItems: [ActionItem(text: "Send the estimate.", atMs: 1_112_000, due: nil)])
        let expected = """
            # Design sync

            2026-10-20 · 1:02:05

            ## Summary

            Agreed to ship.

            ## Bookmarks

            - [01:01] Pricing

            ## Action items

            - [ ] Send the estimate. ([18:32])

            ## Transcript

            [18:32] Others: Ship it.
            [1:02:05] Me: Agreed.
            """
        #expect(TranscriptExporter.markdown(meeting: finished, transcript: transcript) == expected)
    }

    @Test func markdownOmitsEmptySections() {
        let transcript = MeetingTranscript(segments: segments, bookmarks: [], actionItems: [])
        let text = TranscriptExporter.markdown(meeting: meeting, transcript: transcript)
        #expect(!text.contains("## Summary"))
        #expect(!text.contains("## Bookmarks"))
        #expect(!text.contains("## Action items"))
        #expect(text.contains("## Transcript"))
    }
}
