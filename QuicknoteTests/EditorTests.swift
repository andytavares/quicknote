import AppKit
import Foundation
import QuicknoteKit
import Testing

@testable import Quicknote

@Suite struct EditorPaletteTests {
    @Test func hasFiftyDistinctValidColours() {
        let swatches = EditorPalette.swatches
        #expect(swatches.count == 50)
        #expect(Set(swatches).count == 50)
        #expect(swatches.allSatisfy { $0.wholeMatch(of: /#[0-9A-F]{6}/) != nil })
    }

    @Test func keepsTheSixNoteColours() {
        #expect(Array(EditorPalette.swatches.prefix(6)) == AppSettings.noteColorChoices.map(\.hex))
    }
}

@Suite struct EditorFontTests {
    @Test func missingFontFallsBackToSystem() {
        let missing = EditorFont(id: "x", name: "X", postScriptName: "No-Such-Font-Anywhere")
        #expect(missing.nsFont(size: 13) == NSFont.systemFont(ofSize: 13))
    }

    @Test func unknownIdReadsAsSystem() {
        #expect(EditorFont.resolve(id: "nope", size: 13) == NSFont.systemFont(ofSize: 13))
    }

    @Test func sixChoicesAndNamedFontsResolve() {
        #expect(EditorFont.choices.count == 6)
        #expect(EditorFont.resolve(id: "handwritten", size: 13).fontName == "BradleyHandITCTT-Bold")
        #expect(EditorFont.resolve(id: "marker", size: 13).fontName == "MarkerFelt-Thin")
    }

    @Test func settingsListTheSameFonts() {
        #expect(AppSettings.fontChoices.map(\.id) == EditorFont.choices.map(\.id))
    }
}

@Suite struct LinkTriggerTests {
    @Test func detectsPartialTitleAfterOpening() {
        let text = "See [[Lis"
        #expect(
            LinkTrigger.detect(in: text, cursor: 9) == LinkTrigger(range: NSRange(location: 6, length: 3), query: "Lis")
        )
    }

    @Test func detectsBareOpening() {
        #expect(LinkTrigger.detect(in: "[[", cursor: 2)?.query == "")
    }

    @Test func ignoresCursorInsideClosedLink() {
        #expect(LinkTrigger.detect(in: "[[Lisbon]]", cursor: 5) == nil)
    }

    @Test func ignoresCursorAfterClosedLink() {
        #expect(LinkTrigger.detect(in: "[[Lisbon]] and", cursor: 14) == nil)
    }

    @Test func triggersBeforeALaterLink() {
        #expect(LinkTrigger.detect(in: "[[Li and [[Other]]", cursor: 4)?.query == "Li")
    }

    @Test func staysOnItsLine() {
        #expect(LinkTrigger.detect(in: "[[Lis\nnext", cursor: 10) == nil)
    }

    @Test func plainTextHasNoTrigger() {
        #expect(LinkTrigger.detect(in: "no links [here", cursor: 14) == nil)
    }
}

@Suite struct RepeatPickerTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// Monday 26 Oct 2026, 09:00 UTC.
    private let monday = Date(timeIntervalSince1970: 1_793_005_200)

    @Test func presetsMapToRules() {
        #expect(RepeatPreset.never.rule == nil)
        #expect(RepeatPreset.biweekly.rule == RecurrenceRule(frequency: .weekly, interval: 2))
        #expect(RepeatPreset.weekday.rule == RecurrenceParser.parse("every weekday"))
        #expect(RepeatPreset.yearly.rule == RecurrenceRule(frequency: .yearly))
    }

    @Test func freeTextShowsDescriptionAndNextThreeDates() throws {
        let preview = try #require(RepeatPreview.make(from: "every tue and thu", after: monday, calendar: calendar))
        #expect(preview.description == "Weekly on Tuesday and Thursday")
        let days = preview.nextDates.map { calendar.component(.weekday, from: $0) }
        #expect(days == [3, 5, 3])
        #expect(preview.nextDates[0] == monday.addingTimeInterval(86_400))
    }

    @Test func unreadableTextHasNoPreview() {
        #expect(RepeatPreview.make(from: "whenever", after: monday, calendar: calendar) == nil)
    }
}

@Suite struct CalendarEditPolicyTests {
    private func event(id: String? = "E1") -> Note {
        var note = Note(body: "Dentist", kind: .event)
        note.calendarEventId = id
        note.dueAt = Date(timeIntervalSince1970: 1_800_000_000)
        note.dueHasTime = true
        return note
    }

    @Test func changingTypeAwayFromLinkedEventAsks() {
        #expect(CalendarEditPolicy.asksToRemoveEvent(whenChanging: event(), to: .task))
    }

    @Test func noQuestionWithoutCalendarCopyOrWhenStayingEvent() {
        #expect(!CalendarEditPolicy.asksToRemoveEvent(whenChanging: event(id: nil), to: .task))
        #expect(!CalendarEditPolicy.asksToRemoveEvent(whenChanging: event(), to: .event))
        #expect(!CalendarEditPolicy.asksToRemoveEvent(whenChanging: Note(body: "x", kind: .task), to: .note))
    }

    @Test func titleTimeOrRepeatChangeUpdatesEvent() {
        let old = event()
        var retitled = old
        retitled.body = "Dentist at 3"
        var repeating = old
        repeating.recurrence = RecurrenceRule(frequency: .weekly)
        #expect(CalendarEditPolicy.updatesEvent(from: old, to: retitled))
        #expect(CalendarEditPolicy.updatesEvent(from: old, to: repeating))
        #expect(!CalendarEditPolicy.updatesEvent(from: old, to: old))
    }

    @Test func settingATimeOnUnlinkedEventOffersOne() {
        var old = event(id: nil)
        old.dueHasTime = false
        #expect(CalendarEditPolicy.offersEvent(from: old, to: event(id: nil)))
        #expect(!CalendarEditPolicy.offersEvent(from: event(id: nil), to: event(id: nil)))
        #expect(!CalendarEditPolicy.offersEvent(from: old, to: event()))
    }
}

@Suite @MainActor struct SaveDebouncerTests {
    @Test func rapidEditsSaveOnce() async throws {
        var saves = 0
        let debouncer = SaveDebouncer(delay: .milliseconds(60)) { saves += 1 }
        for _ in 0..<5 { debouncer.schedule() }
        #expect(saves == 0)
        try await Task.sleep(for: .milliseconds(250))
        #expect(saves == 1)
        #expect(!debouncer.hasPendingSave)
    }

    @Test func flushSavesPendingEditNowAndOnlyOnce() async throws {
        var saves = 0
        let debouncer = SaveDebouncer(delay: .milliseconds(60)) { saves += 1 }
        debouncer.schedule()
        debouncer.flush()
        debouncer.flush()
        try await Task.sleep(for: .milliseconds(200))
        #expect(saves == 1)
    }
}

@Suite struct FlowLayoutTests {
    @Test func keepsOneRowWhenEverythingFits() {
        #expect(FlowLayout.rows(widths: [50, 50, 50], maxWidth: 200, spacing: 8) == [0..<3])
    }

    @Test func startsANewRowWhenTheNextItemDoesNotFit() {
        #expect(FlowLayout.rows(widths: [90, 90, 90, 40], maxWidth: 200, spacing: 8) == [0..<2, 2..<4])
    }

    @Test func countsSpacingWhenFilling() {
        #expect(FlowLayout.rows(widths: [100, 100], maxWidth: 200, spacing: 8) == [0..<1, 1..<2])
    }

    @Test func givesAnItemWiderThanTheRowARowOfItsOwn() {
        #expect(FlowLayout.rows(widths: [300, 50], maxWidth: 200, spacing: 8) == [0..<1, 1..<2])
        #expect(FlowLayout.rows(widths: [], maxWidth: 200, spacing: 8).isEmpty)
    }
}
