import Foundation
import Testing

@testable import QuicknoteKit

struct DailyBriefSpokenTextTests {
    private let calendar = ReminderFixtures.calendar
    private func date(_ hour: Int, _ minute: Int = 0, day: Int = 25) -> Date {
        ReminderFixtures.date(10, day, hour, minute)
    }
    private func brief(hour: Int, _ notes: [Note] = [], _ events: [BriefEvent] = []) -> DailyBrief {
        let day = BriefDay(now: date(hour), calendar: calendar)
        return DailyBriefBuilder.build(notes: notes, events: events, day: day)
    }
    private func event(_ title: String, _ start: Date, allDay: Bool = false) -> BriefEvent {
        BriefEvent(
            title: title, start: start, end: start.addingTimeInterval(3600), isAllDay: allDay,
            calendarTitle: "Home", colorHex: "#2F6FED", eventIdentifier: nil)
    }

    @Test func readsEveryNonEmptySectionInOrder() {
        var done = ReminderFixtures.note("Done", id: 9, due: date(9))
        done.completedAt = date(7)
        let notes = [
            ReminderFixtures.note("Pay rent", id: 1, due: date(15)),
            ReminderFixtures.note("Water plants", id: 2, due: date(0), timed: false),
            ReminderFixtures.note("Renew passport", id: 3, due: date(9, day: 20)),
            done,
        ]
        let events = [event("Call with Mum", date(16, 30)), event("Brunch with Ana", date(10))]
        #expect(
            brief(hour: 8, notes, events).spokenText(calendar: calendar)
                == "Good morning. Today is Sunday, 25 October. You have 2 events: Brunch with Ana at 10 AM, "
                + "Call with Mum at 4:30 PM. 2 tasks are due today: Pay rent at 3 PM, Water plants. "
                + "1 overdue: Renew passport.")
    }

    @Test func skipsEmptySectionsAndSaysSoWhenNothingIsPlanned() {
        #expect(
            brief(hour: 14).spokenText(calendar: calendar)
                == "Good afternoon. Today is Sunday, 25 October. Nothing planned today.")
    }

    @Test func singularsAllDayEventsAndEveningGreeting() {
        let notes = [ReminderFixtures.note("Call", kind: .note, id: 1).snoozed(until: date(21))]
        let text = brief(hour: 19, notes, [event("Holiday", date(0), allDay: true)]).spokenText(calendar: calendar)
        #expect(
            text == "Good evening. Today is Sunday, 25 October. You have 1 event: Holiday, all day. "
                + "1 note is coming back: Call at 9 PM.")
    }
}
