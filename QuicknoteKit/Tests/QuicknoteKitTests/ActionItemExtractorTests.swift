import Foundation
import Testing

@testable import QuicknoteKit

struct ActionItemExtractorTests {
    // Sunday 25 October 2026, noon.
    let now = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 12))!

    func segment(_ text: String, startMs: Int = 0) -> TranscriptSegment {
        TranscriptSegment(
            meetingId: 1, line: SpokenLine(span: startMs..<(startMs + 5_000), speaker: .others, text: text))
    }

    func items(_ text: String, startMs: Int = 0) -> [ActionItem] {
        ActionItemExtractor.actionItems(in: [segment(text, startMs: startMs)], now: now)
    }

    @Test func findsTheS18SampleWithItsDueFriday() {
        let found = items(
            "So the pricing table moves under the fold. Action item: Dana will send the revised estimate by Friday.",
            startMs: 1_112_000)
        #expect(found.count == 1)
        #expect(found.first?.text == "Dana will send the revised estimate by Friday.")
        #expect(found.first?.atMs == 1_112_000)
        let friday = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 30))
        #expect(found.first?.due == friday)
    }

    @Test func findsFirstPersonCommitments() {
        #expect(items("I'll book the room for the user test.").map(\.text) == ["I'll book the room for the user test."])
        #expect(items("i will email the vendor.").map(\.text) == ["I will email the vendor."])
        #expect(items("I’ll check the build.").count == 1)
    }

    @Test func findsEachPhrase() {
        let sentences = [
            "We need to rewrite onboarding.", "Can you review the draft?", "Let's make sure legal sees it.",
            "Add it to the todo list.", "Put that on the to-do list.", "Priya will own the launch.",
        ]
        for sentence in sentences { #expect(items(sentence).count == 1, "\(sentence)") }
    }

    @Test func ignoresPlainConversation() {
        #expect(items("We talked about the weather.").isEmpty)
        #expect(items("It will rain tomorrow.").isEmpty)
        #expect(items("The tool will help us.").isEmpty)
    }

    @Test func dueDatesFromTomorrowAndNextWeek() {
        let tomorrow = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 26))
        let nextWeek = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 1))
        #expect(items("I'll send it tomorrow.").first?.due == tomorrow)
        #expect(items("I'll send it next week.").first?.due == nextWeek)
        #expect(items("I'll send it.").first?.due == nil)
    }

    @Test func removesNearIdenticalRepeats() {
        let segments = [segment("I'll book the room.", startMs: 1_000), segment("I'll book the room!", startMs: 9_000)]
        let found = ActionItemExtractor.actionItems(in: segments, now: now)
        #expect(found.map(\.atMs) == [1_000])
    }
}
