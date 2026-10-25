import Foundation
import GRDB
import QuicknoteKit
import Testing

@testable import Quicknote

/// Hits have no public initialiser, so the tests search a small real database.
private func seededSearch() throws -> SearchIndex {
    let database = try AppDatabase.inMemory()
    try database.writer.write { db in
        var pricing = Note(body: "Call about pricing page")
        try pricing.insert(db)
        var budget = Note(body: "Budget plan")
        try budget.insert(db)
        let file = StoredFile(fileName: "budget.pdf", relativePath: "a/budget.pdf", byteCount: 1)
        var attachment = Attachment(noteId: budget.id!, kind: .file, file: file)
        try attachment.insert(db)
        var meeting = Meeting(noteId: pricing.id!, title: "Weekly sync")
        try meeting.insert(db)
        let line = SpokenLine(span: 1_112_000..<1_115_000, speaker: .others, text: "the pricing table moves")
        var segment = TranscriptSegment(meetingId: meeting.id!, line: line)
        try segment.insert(db)
    }
    return SearchIndex(database: database)
}

private func rows(_ query: String) throws -> [SearchRow] {
    try seededSearch().search(query, limitPerGroup: 5).rows
}

struct SearchSnippetTests {
    @Test func marksBecomeHighlightedRanges() {
        let attributed = SearchSnippet.attributed("Call about «pricing» and «plans» today")
        let highlighted = attributed.runs.filter { $0.inlinePresentationIntent != nil }.map {
            String(attributed[$0.range].characters)
        }
        #expect(String(attributed.characters) == "Call about pricing and plans today")
        #expect(highlighted == ["pricing", "plans"])
    }

    @Test func snippetWithoutMarksHasNoHighlight() {
        let attributed = SearchSnippet.attributed("plain text")
        #expect(attributed.runs.allSatisfy { $0.inlinePresentationIntent == nil })
        #expect(String(attributed.characters) == "plain text")
    }

    @Test func unclosedMarkHighlightsToTheEnd() {
        let attributed = SearchSnippet.attributed("a «b")
        #expect(String(attributed.characters) == "a b")
        #expect(attributed.runs.last?.inlinePresentationIntent != nil)
    }
}

struct SearchRowTests {
    @Test func rowsKeepGroupOrderAndSkipEmptyGroups() throws {
        #expect(try rows("pricing").map(\.group) == [.notes, .transcripts])
        #expect(try rows("budget").map(\.group) == [.notes, .files])
    }

    @Test func openActionsMapEachGroupToItsEntryPoint() throws {
        let pricing = try rows("pricing")
        let budget = try rows("budget")
        #expect(pricing[0].openAction == .note(id: 1))
        #expect(pricing[1].openAction == .meeting(id: 1, atMs: 1_112_000))
        #expect(budget[1].openAction == .note(id: 2))
    }

    @Test func transcriptShowsMinutesAndSeconds() throws {
        let pricing = try rows("pricing")
        #expect(pricing[1].timestamp == "18:32")
        #expect(pricing[0].timestamp == nil)
    }

    @Test func accessibilityLabelHasNoMarksAndNamesTheMeeting() throws {
        let label = try rows("pricing")[1].accessibilityLabel
        #expect(label == "Meeting transcripts: the pricing table moves, Weekly sync at 18:32")
    }
}

@MainActor
struct SearchModelTests {
    private func model(debounce: Duration = .milliseconds(1)) throws -> SearchModel {
        let index = try seededSearch()
        return SearchModel(debounce: debounce) { query in
            (try? index.search(query, limitPerGroup: 5).rows) ?? []
        }
    }

    @Test func selectionMovesAcrossGroupsAndClampsAtTheEnds() async throws {
        let model = try model()
        model.query = "budget"
        await model.settle()
        model.moveSelection(by: -1)
        #expect(model.selectedIndex == 0)
        model.moveSelection(by: 1)
        #expect(model.selectedRow?.group == .files)
        model.moveSelection(by: 1)
        #expect(model.selectedIndex == 1)
    }

    @Test func selectionSkipsAnEmptyGroupBetweenTwoFullOnes() async throws {
        let model = try model()
        model.query = "budget"
        await model.settle()
        #expect(model.rows.map(\.group) == [.notes, .files])
        model.moveSelection(by: 1)
        #expect(model.selectedRow?.group == .files)
    }

    @Test func newQueryCancelsThePreviousSearch() async throws {
        let model = try model(debounce: .milliseconds(40))
        model.query = "budget"
        model.query = "pricing"
        await model.settle()
        #expect(model.rows.map(\.group) == [.notes, .transcripts])
    }

    @Test func blankQueryClearsResultsAndShowsEmptyState() async throws {
        let model = try model()
        model.query = "pricing"
        await model.settle()
        #expect(model.hasSearched)
        model.query = "  "
        #expect(model.rows.isEmpty)
        #expect(!model.hasSearched)
    }
}
