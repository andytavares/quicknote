import CoreMedia
import Foundation
import QuicknoteKit
import Testing

@testable import Quicknote

private final class FakeSession: SpeechSession {
    let updates: AsyncStream<TranscriptUpdate>
    let updateContinuation: AsyncStream<TranscriptUpdate>.Continuation
    let levels = AsyncStream<Float> { $0.finish() }
    var lines: [SpokenLine]
    private(set) var cancelled = false

    init(words: String) {
        (updates, updateContinuation) = AsyncStream.makeStream()
        lines = words.isEmpty ? [] : [SpokenLine(span: 0..<900, speaker: .me, text: words)]
    }

    func start() async throws {}
    func finish() async throws -> [SpokenLine] { lines }
    func cancel() async { cancelled = true }
}

private final class FakePresenter: HoldToTalkPresenting {
    var events: [String] = []
    var undo: (() -> Void)?
    func showPreparing() { events.append("preparing") }
    func showListening() { events.append("listening") }
    func showFinishing() { events.append("finishing") }
    func showLive(text: String, chip: String?) { events.append("live \(text) | \(chip ?? "-")") }
    func showLevel(_ level: Float) {}
    func showSaved(title: String, detail: String, undo: @escaping () -> Void) {
        events.append("saved \(title) | \(detail)")
        self.undo = undo
    }
    func showError(_ message: String) { events.append("error \(message)") }
    func hide() { events.append("hide") }
}

@MainActor
private final class Harness {
    // Wednesday 21 Oct 2026, 09:00 UTC.
    var clock = Date(timeIntervalSince1970: 1_792_573_200)
    let presenter = FakePresenter()
    let repository: NoteRepository
    var sessions: [FakeSession] = []
    var words = "remind me at 6 to pick up the dry cleaning"
    var confirmedEvents: [Int64] = []
    var context: CapturedContext? = CapturedContext(
        appBundleId: "com.apple.Safari", appName: "Safari", siteHost: "figma.com", url: "https://figma.com/x")
    var permitted = true
    var holdToTalk: HoldToTalk!

    init() throws {
        repository = NoteRepository(database: try .inMemory())
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        holdToTalk = HoldToTalk(
            services: HoldToTalkServices(
                ensurePermissions: { [unowned self] in
                    await Task.yield()
                    return permitted
                },
                frontmostContext: { [unowned self] in context },
                makeSession: { [unowned self] in
                    let session = FakeSession(words: words)
                    sessions.append(session)
                    return session
                },
                confirmEvent: { [unowned self] in confirmedEvents.append($0) },
                repository: repository,
                now: { [unowned self] in clock },
                calendar: calendar),
            presenter: presenter)
    }

    struct NotSaved: Error {}

    func savedNoteId() throws -> Int64 {
        guard case .saved(let noteId) = holdToTalk.state else { throw NotSaved() }
        return noteId
    }

    func hold(seconds: TimeInterval) async {
        holdToTalk.keyDown()
        await holdToTalk.settled()
        clock.addTimeInterval(seconds)
        holdToTalk.keyUp()
        await holdToTalk.settled()
    }
}

@MainActor
struct HoldToTalkTests {
    @Test func releaseAfterAHoldSavesAClassifiedNoteWithContext() async throws {
        let harness = try Harness()
        await harness.hold(seconds: 2)

        let noteId = try harness.savedNoteId()
        let note = try #require(try harness.repository.note(id: noteId))
        #expect(note.kind == .reminder)
        #expect(note.body == "remind me at 6 to pick up the dry cleaning")
        #expect(note.siteHost == "figma.com")
        #expect(note.appName == "Safari")
        #expect(
            harness.presenter.events.contains {
                $0.hasPrefix("saved remind me at 6") && $0.contains("Reminder · Today, 18:00")
            })
    }

    @Test func undoDeletesTheSavedNote() async throws {
        let harness = try Harness()
        await harness.hold(seconds: 1)
        let noteId = try harness.savedNoteId()

        harness.presenter.undo?()

        #expect(try harness.repository.note(id: noteId) == nil)
    }

    @Test func holdShorterThanThreeTenthsOfASecondCancelsSilently() async throws {
        let harness = try Harness()
        await harness.hold(seconds: 0.2)

        #expect(harness.holdToTalk.state == .cancelled)
        #expect(try harness.repository.notes(matching: .inbox).isEmpty)
        #expect(!harness.presenter.events.contains { $0.hasPrefix("saved") || $0.hasPrefix("error") })
        #expect(harness.sessions.first?.cancelled == true)
    }

    @Test func releaseWithNoWordsCancels() async throws {
        let harness = try Harness()
        harness.words = ""
        await harness.hold(seconds: 2)

        #expect(harness.holdToTalk.state == .cancelled)
        #expect(try harness.repository.notes(matching: .inbox).isEmpty)
    }

    @Test func releaseBeforePermissionResolvesNeverStartsListening() async throws {
        let harness = try Harness()
        harness.holdToTalk.keyDown()
        harness.holdToTalk.keyUp()
        await harness.holdToTalk.settled()

        #expect(harness.holdToTalk.state == .cancelled)
        #expect(harness.sessions.isEmpty)
    }

    @Test func deniedPermissionCancels() async throws {
        let harness = try Harness()
        harness.permitted = false
        await harness.hold(seconds: 2)

        #expect(harness.holdToTalk.state == .cancelled)
        #expect(harness.sessions.isEmpty)
    }

    @Test func pressingAgainWhileFinishingIsIgnored() async throws {
        let harness = try Harness()
        harness.holdToTalk.keyDown()
        await harness.holdToTalk.settled()
        harness.clock.addTimeInterval(2)
        harness.holdToTalk.keyUp()
        #expect(harness.holdToTalk.state == .finishing)

        harness.holdToTalk.keyDown()
        await harness.holdToTalk.settled()

        #expect(harness.sessions.count == 1)
        #expect(try harness.repository.notes(matching: .inbox).count == 1)
    }

    @Test func captionTargetReceivesTheTranscriptInsteadOfANote() async throws {
        let harness = try Harness()
        var captions: [String] = []
        harness.holdToTalk.captionTarget = { captions.append($0) }
        await harness.hold(seconds: 2)

        #expect(captions == ["remind me at 6 to pick up the dry cleaning"])
        #expect(try harness.repository.notes(matching: .inbox).isEmpty)
        #expect(harness.holdToTalk.state == .idle)
    }

    @Test func eventsAskToBeAddedToTheCalendar() async throws {
        let harness = try Harness()
        harness.words = "Call Mira tomorrow at 10"
        await harness.hold(seconds: 2)

        let noteId = try harness.savedNoteId()
        #expect(harness.confirmedEvents == [noteId])
    }

    @Test func liveTextShowsTheDetectedTypeAsYouTalk() async throws {
        let harness = try Harness()
        harness.holdToTalk.keyDown()
        await harness.holdToTalk.settled()
        harness.sessions[0].updateContinuation.yield(.partial("bug: crash on launch"))
        for _ in 0..<5 { await Task.yield() }

        #expect(harness.presenter.events.contains("live bug: crash on launch | Bug"))
    }
}

struct VoiceNoteTests {
    @Test func trimsTextAndLeavesNoContextWhenThereIsNone() {
        let note = VoiceNote.make(text: "  buy milk \n", context: nil, now: Date(), calendar: .current)
        #expect(note.body == "buy milk")
        #expect(note.kind == .task)
        #expect(note.appBundleId == nil)
    }
}

struct LiveTranscriberTimingTests {
    @Test func analyzerTimeRangesBecomeMilliseconds() {
        let range = CMTimeRange(
            start: CMTime(seconds: 1.25, preferredTimescale: 600),
            duration: CMTime(seconds: 2.5, preferredTimescale: 600))
        #expect(LiveTranscriber.span(of: range) == 1250..<3750)
    }

    @Test func invalidTimesCollapseToZero() {
        #expect(LiveTranscriber.span(of: CMTimeRange(start: .invalid, end: .invalid)) == 0..<0)
    }
}
