import Foundation
import Testing

@testable import QuicknoteKit

struct RecurrenceRuleTests {
    @Test func weeklyRuleWithWeekdaysPicksTheNextListedDay() {
        let rule = RecurrenceRule(frequency: .weekly, weekdays: [3, 5])
        let tuesday = newYorkDate(2026, 10, 27, 9)
        #expect(rule.nextOccurrence(after: tuesday, calendar: newYorkCalendar) == newYorkDate(2026, 10, 29, 9))
        let thursday = newYorkDate(2026, 10, 29, 9)
        #expect(rule.nextOccurrence(after: thursday, calendar: newYorkCalendar) == newYorkDate(2026, 11, 3, 9))
    }

    @Test func everyOtherWeekWithAWeekdaySkipsAWeek() {
        let rule = RecurrenceRule(frequency: .weekly, interval: 2, weekdays: [3])
        let tuesday = newYorkDate(2026, 10, 27, 9)
        #expect(rule.nextOccurrence(after: tuesday, calendar: newYorkCalendar) == newYorkDate(2026, 11, 10, 9))
    }

    @Test func weeklyWithoutWeekdaysRepeatsOnTheSameWeekday() {
        let rule = RecurrenceRule(frequency: .weekly, interval: 2)
        let sunday = newYorkDate(2026, 10, 25, 9)
        #expect(rule.nextOccurrence(after: sunday, calendar: newYorkCalendar) == newYorkDate(2026, 11, 8, 9))
    }

    @Test func dailyRuleKeepsWallClockAcrossTheDSTChange() {
        let rule = RecurrenceRule(frequency: .daily)
        let saturday = newYorkDate(2026, 10, 31, 9)
        let next = rule.nextOccurrence(after: saturday, calendar: newYorkCalendar)
        #expect(next == newYorkDate(2026, 11, 1, 9))
        #expect(next.timeIntervalSince(saturday) == 25 * 3600)
    }

    @Test func monthlyRuleClampsToTheEndOfShorterMonths() {
        let rule = RecurrenceRule(frequency: .monthly)
        let next = rule.nextOccurrence(after: newYorkDate(2027, 1, 31, 9), calendar: newYorkCalendar)
        #expect(next == newYorkDate(2027, 2, 28, 9))
    }

    @Test func yearlyRuleAddsYears() {
        let rule = RecurrenceRule(frequency: .yearly, interval: 2)
        let next = rule.nextOccurrence(after: newYorkDate(2026, 3, 4, 8), calendar: newYorkCalendar)
        #expect(next == newYorkDate(2028, 3, 4, 8))
    }

    @Test func noteStoresItsRuleAsJSONAndClearsIt() {
        var note = Note(body: "Water plants")
        let rule = RecurrenceRule(frequency: .weekly, interval: 2, weekdays: [2, 4])
        note.recurrence = rule
        #expect(note.recurrenceJSON != nil)
        #expect(note.recurrence == rule)
        note.recurrence = nil
        #expect(note.recurrenceJSON == nil)
        note.recurrenceJSON = "not json"
        #expect(note.recurrence == nil)
    }
}
