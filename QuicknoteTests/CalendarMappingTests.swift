import EventKit
import Foundation
import QuicknoteKit
import Testing

@testable import Quicknote

struct CalendarMappingTests {
    private let due = Date(timeIntervalSince1970: 1_792_000_000)

    private func timedNote(_ rule: RecurrenceRule? = nil) -> Note {
        var note = Note(body: "Call Jonah\nabout pricing", kind: .event)
        note.dueAt = due
        note.dueHasTime = true
        note.url = "https://example.com/pricing"
        note.recurrence = rule
        return note
    }

    @Test func dailyRuleMapsToDaily() {
        let rule = RecurrenceRule(frequency: .daily).eventKitRule
        #expect(rule.frequency == .daily && rule.interval == 1 && rule.daysOfTheWeek == nil)
    }

    @Test func weeklyRuleKeepsItsWeekdays() {
        let rule = RecurrenceRule(frequency: .weekly, weekdays: [2, 4]).eventKitRule
        #expect(rule.frequency == .weekly)
        #expect(rule.daysOfTheWeek?.map(\.dayOfTheWeek.rawValue) == [2, 4])
    }

    @Test func everyTwoWeeksKeepsTheInterval() {
        let rule = RecurrenceRule(frequency: .weekly, interval: 2).eventKitRule
        #expect(rule.interval == 2 && rule.daysOfTheWeek == nil)
    }

    @Test func monthlyAndYearlyMap() {
        #expect(RecurrenceRule(frequency: .monthly).eventKitRule.frequency == .monthly)
        #expect(RecurrenceRule(frequency: .yearly).eventKitRule.frequency == .yearly)
    }

    @Test func timedNoteBecomesATimedEventWithTheChosenDuration() throws {
        let draft = try #require(EventDraft(note: timedNote(), duration: 45 * 60))
        #expect(draft.title == "Call Jonah")
        #expect(draft.notes == "Call Jonah\nabout pricing")
        #expect(draft.url == URL(string: "https://example.com/pricing"))
        #expect(draft.start == due && draft.end == due.addingTimeInterval(45 * 60))
        #expect(!draft.isAllDay)
    }

    @Test func noteWithoutATimeBecomesAllDay() throws {
        var note = timedNote()
        note.dueHasTime = false
        let draft = try #require(EventDraft(note: note, duration: 1800))
        #expect(draft.isAllDay)
    }

    @Test func noteWithoutADueDateHasNoDraft() {
        #expect(EventDraft(note: Note(body: "x"), duration: 1800) == nil)
    }

    @Test func draftWritesItsFieldsAndRepeatToAnEvent() throws {
        let draft = try #require(EventDraft(note: timedNote(RecurrenceRule(frequency: .daily)), duration: 1800))
        let event = EKEvent(eventStore: EKEventStore())
        draft.apply(to: event)
        #expect(event.title == "Call Jonah" && event.startDate == due && event.endDate == due.addingTimeInterval(1800))
        #expect(event.recurrenceRules?.first?.frequency == .daily)
    }

    @Test func eventMapsToBriefEvent() {
        let event = EKEvent(eventStore: EKEventStore())
        event.title = "Brunch with Ana"
        event.startDate = due
        event.endDate = due.addingTimeInterval(3600)
        let brief = BriefEvent(event: event)
        #expect(brief.title == "Brunch with Ana" && brief.start == due && !brief.isAllDay)
        #expect(brief.end == due.addingTimeInterval(3600))
    }

    @Test func movedEventUpdatesTheDueDate() throws {
        let moved = due.addingTimeInterval(7200)
        let note = try #require(EventSyncRule.reconciled(timedNote(), eventStart: moved))
        #expect(note.dueAt == moved)
    }

    @Test func deletedEventClearsTheEventId() throws {
        var note = timedNote()
        note.calendarEventId = "ABC"
        let result = try #require(EventSyncRule.reconciled(note, eventStart: nil))
        #expect(result.calendarEventId == nil && result.dueAt == due)
    }

    @Test func unchangedEventChangesNothing() {
        #expect(EventSyncRule.reconciled(timedNote(), eventStart: due) == nil)
    }
}
