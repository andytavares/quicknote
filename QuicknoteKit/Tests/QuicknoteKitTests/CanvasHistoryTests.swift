import CoreGraphics
import Testing

@testable import QuicknoteKit

struct CanvasHistoryTests {
    private func document(caption: String) -> CanvasDocument {
        CanvasDocument(background: .card(style: .kraft, size: .story), caption: caption)
    }

    @Test func undoReturnsThePreviousState() {
        var history = CanvasHistory()
        history.record(document(caption: "a"))
        history.record(document(caption: "b"))
        #expect(history.undo()?.caption == "a")
        #expect(history.undo() == nil)
    }

    @Test func replacingTheLatestStateKeepsOneUndoStep() {
        var history = CanvasHistory()
        history.record(document(caption: "a"))
        history.record(document(caption: "b"))
        history.replaceLatest(with: document(caption: "bc"))
        #expect(history.undo()?.caption == "a")
        #expect(history.redo()?.caption == "bc")
    }

    @Test func redoReplaysUndoneStates() {
        var history = CanvasHistory()
        history.record(document(caption: "a"))
        history.record(document(caption: "b"))
        _ = history.undo()
        #expect(history.redo()?.caption == "b")
        #expect(history.redo() == nil)
    }

    @Test func recordingAfterUndoDropsTheRedoBranch() {
        var history = CanvasHistory()
        history.record(document(caption: "a"))
        history.record(document(caption: "b"))
        _ = history.undo()
        history.record(document(caption: "c"))
        #expect(history.redo() == nil)
        #expect(history.undo()?.caption == "a")
    }

    @Test func historyKeepsOnlyTheLastHundredStates() {
        var history = CanvasHistory()
        for index in 0..<150 { history.record(document(caption: "\(index)")) }
        var undone = 0
        var oldest: CanvasDocument?
        while let previous = history.undo() {
            undone += 1
            oldest = previous
        }
        #expect(undone == 99)
        #expect(oldest?.caption == "50")
    }

    @Test func emptyHistoryHasNothingToUndoOrRedo() {
        var history = CanvasHistory()
        #expect(history.undo() == nil)
        #expect(history.redo() == nil)
    }
}
