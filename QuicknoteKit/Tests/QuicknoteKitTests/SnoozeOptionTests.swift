import Foundation
import Testing

@testable import QuicknoteKit

struct SnoozeOptionTests {
    private let calendar = ReminderFixtures.calendar
    private func date(_ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        ReminderFixtures.date(month, day, hour, minute)
    }

    @Test func morningOffersAllFiveChoices() {
        let now = date(10, 25, 9, 30)
        let options = SnoozeOption.options(now: now, calendar: calendar)
        #expect(options.map(\.title) == ["15 minutes", "1 hour", "This evening", "Tomorrow morning", "Next week"])
        #expect(
            options.map(\.until) == [
                date(10, 25, 9, 45), date(10, 25, 10, 30), date(10, 25, 20), date(10, 26, 9), date(10, 26, 9),
            ])
    }

    @Test func eveningChoiceIsHiddenFromSevenOClock() {
        let titles: (Date) -> [String] = { SnoozeOption.options(now: $0, calendar: calendar).map(\.title) }
        #expect(titles(date(10, 25, 18, 59)).contains("This evening"))
        #expect(!titles(date(10, 25, 19, 0)).contains("This evening"))
    }

    @Test func nextWeekOnMondayMeansTheFollowingMondayAcrossDaylightSaving() {
        let options = SnoozeOption.options(now: date(10, 26, 8, 0), calendar: calendar)
        #expect(options.last?.title == "Next week")
        #expect(options.last?.until == date(11, 2, 9))
    }

    @Test func tomorrowMorningCrossesMonthEnd() {
        let options = SnoozeOption.options(now: date(10, 31, 23, 0), calendar: calendar)
        #expect(options.first { $0.title == "Tomorrow morning" }?.until == date(11, 1, 9))
    }

    @Test func snoozedSetsTimeAndPutsNoteBackOnEdge() {
        var note = ReminderFixtures.note("Call bank")
        note.onEdge = false
        let snoozed = note.snoozed(until: date(10, 25, 20))
        #expect(snoozed.snoozedUntil == date(10, 25, 20))
        #expect(snoozed.onEdge)
        #expect(snoozed.body == "Call bank")
    }
}
