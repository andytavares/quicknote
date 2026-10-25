import Testing

@testable import QuicknoteKit

struct NoteLinkParserTests {
    @Test func returnsTrimmedTitlesInOrderWithoutDuplicates() {
        let body = "See [[ Pricing ]] and [[Roadmap]] then [[Pricing]] again"
        #expect(NoteLinkParser.linkedTitles(in: body) == ["Pricing", "Roadmap"])
    }

    @Test func ignoresEmptyAndUnclosedLinks() {
        #expect(NoteLinkParser.linkedTitles(in: "a [[]] b [[  ]] c [[open") == [])
    }

    @Test func linkDoesNotSpanLines() {
        #expect(NoteLinkParser.linkedTitles(in: "[[one\ntwo]]") == [])
    }

    @Test func keepsEmojiTitles() {
        #expect(NoteLinkParser.linkedTitles(in: "[[🚀 Launch]]") == ["🚀 Launch"])
    }
}
