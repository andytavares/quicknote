import Foundation
import QuicknoteKit
import Testing

@testable import Quicknote

struct EdgeModelTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)
    private let slack = CapturedContext(appBundleId: "com.tinyspeck.slackmacgap", appName: "Slack")
    private let xcode = CapturedContext(appBundleId: "com.apple.dt.Xcode", appName: "Xcode")

    private func note(_ body: String, id: Int64, pinnedTo context: CapturedContext? = nil) -> Note {
        var note = Note(body: body, now: now)
        note.id = id
        note.appBundleId = context?.appBundleId
        note.pinnedToContext = context != nil
        return note
    }

    @Test func pinnedNotesSlideOutInTheirAppAndLeaveTheTabsAlone() {
        let model = EdgeModel()
        model.update(
            notes: [note("Loose", id: 1), note("For Slack", id: 2, pinnedTo: slack)], context: slack, now: now)
        #expect(model.contextNotes.map(\.title) == ["For Slack"])
        #expect(model.tabNotes.map(\.title) == ["Loose"])
        #expect(model.isContextCardShown)
        #expect(model.tabCount == 2)
    }

    @Test func pinnedNotesHideAgainInOtherApps() {
        let model = EdgeModel()
        let notes = [note("For Slack", id: 2, pinnedTo: slack)]
        model.update(notes: notes, context: slack, now: now)
        model.update(notes: notes, context: xcode, now: now)
        #expect(model.contextNotes.isEmpty)
        #expect(model.tabCount == 0)
        #expect(!model.isContextCardShown)
    }

    @Test func aDismissedCardStaysDismissedUntilTheContextChanges() {
        let model = EdgeModel()
        let notes = [note("For Slack", id: 2, pinnedTo: slack)]
        model.update(notes: notes, context: slack, now: now)
        model.isContextCardShown = false
        model.update(notes: notes, context: slack, now: now)
        #expect(!model.isContextCardShown)
        model.update(notes: notes, context: xcode, now: now)
        model.update(notes: notes, context: slack, now: now)
        #expect(model.isContextCardShown)
    }

    @Test func withTheSettingOffPinnedNotesDoNotPopOut() {
        let model = EdgeModel()
        model.popsUpContextNotes = false
        model.update(notes: [note("For Slack", id: 2, pinnedTo: slack)], context: slack, now: now)
        #expect(model.contextNotes.isEmpty)
        #expect(!model.isContextCardShown)
    }

    @Test func revealOpensOnlyNotesThatAreOnTheEdge() {
        let model = EdgeModel()
        model.update(notes: [note("Loose", id: 1)], context: nil, now: now)
        model.reveal(noteId: 99)
        #expect(model.expandedNoteId == nil)
        model.reveal(noteId: 1)
        #expect(model.expandedNoteId == 1)
    }

    @Test func anExpandedCardClosesWhenItsNoteLeavesTheEdge() {
        let model = EdgeModel()
        var loose = note("Loose", id: 1)
        model.update(notes: [loose], context: nil, now: now)
        model.reveal(noteId: 1)
        loose.onEdge = false
        model.update(notes: [loose], context: nil, now: now)
        #expect(model.expandedNoteId == nil)
    }

    @Test func clickingTheOpenTabClosesItsCardWhileThePointerStaysOnTheTab() {
        let model = EdgeModel()
        model.update(notes: [note("Loose", id: 1)], context: nil, now: now)
        model.peekedNoteId = 1
        model.toggleCard(noteId: 1)
        #expect(model.card?.id == "expanded-1")
        model.toggleCard(noteId: 1)
        #expect(model.card == nil)
    }

    @Test func clickingAnotherTabSwitchesTheCard() {
        let model = EdgeModel()
        model.update(notes: [note("One", id: 1), note("Two", id: 2)], context: nil, now: now)
        model.toggleCard(noteId: 1)
        model.toggleCard(noteId: 2)
        #expect(model.card?.id == "expanded-2")
    }
}

struct EdgeCardTests {
    private func note(id: Int64) -> Note {
        var note = Note(body: "Note \(id)")
        note.id = id
        return note
    }

    @Test func theTabOfTheShownNoteIsTheCurrentOne() {
        for card in [EdgeCard.peek(note(id: 1)), .expanded(note(id: 1))] {
            #expect(card.shows(.note(note(id: 1))))
            #expect(!card.shows(.note(note(id: 2))))
            #expect(!card.shows(.context))
        }
    }

    @Test func theContextTabIsCurrentOnlyWhileTheContextCardShows() {
        #expect(EdgeCard.context.shows(.context))
        #expect(!EdgeCard.context.shows(.note(note(id: 1))))
        #expect(!EdgeCard.context.shows(.overflow(3)))
    }
}
