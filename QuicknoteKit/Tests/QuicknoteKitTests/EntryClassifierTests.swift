import Foundation
import Testing

@testable import QuicknoteKit

struct EntryClassifierTests {
    let now = newYorkDate(2026, 10, 25, 9)

    func classify(_ text: String, now: Date? = nil) -> Classification {
        EntryClassifier.classify(text, now: now ?? self.now, calendar: newYorkCalendar)
    }

    @Test func dateAndTimeMakeAnEvent() {
        let result = classify("Call Mira tomorrow at 10")
        #expect(result.kind == .event)
        #expect(result.due == newYorkDate(2026, 10, 26, 10))
        #expect(result.hasTime)
    }

    @Test func aVerbFirstMakesATaskWithoutADueDate() {
        let result = classify("Buy milk")
        #expect(result.kind == .task)
        #expect(result.due == nil)
        #expect(result.recurrence == nil)
    }

    @Test func reminderWithTimeOnlyUsesTodayWhenTheTimeIsAhead() {
        let result = classify("remind me at 6 to pick up the dry cleaning")
        #expect(result.kind == .reminder)
        #expect(result.due == newYorkDate(2026, 10, 25, 18))
        #expect(result.hasTime)
    }

    @Test func reminderWithTimeOnlyRollsToTomorrowWhenTheTimePassed() {
        let result = classify("remind me at 6 to pick up the dry cleaning", now: newYorkDate(2026, 10, 25, 19))
        #expect(result.due == newYorkDate(2026, 10, 26, 18))
    }

    @Test func reminderWithDateOnlyDefaultsToNineAM() {
        let result = classify("remind me tomorrow to call Mom")
        #expect(result.kind == .reminder)
        #expect(result.due == newYorkDate(2026, 10, 26, 9))
        #expect(!result.hasTime)
    }

    @Test func repeatPhraseMakesATaskWithARule() {
        let result = classify("water plants every tue and thu")
        #expect(result.kind == .task)
        #expect(result.recurrence == RecurrenceRule(frequency: .weekly, weekdays: [3, 5]))
        #expect(result.due == nil)
    }

    @Test func repeatDayNamesAreNotReadAsADueDate() {
        #expect(classify("Standup every Monday").due == nil)
    }

    @Test func aLoneURLIsABookmark() {
        #expect(classify("https://www.figma.com/design/pricing-v3").kind == .bookmark)
        #expect(classify("  https://example.com/a?b=1\n").kind == .bookmark)
    }

    @Test func aURLInsideASentenceIsNotABookmark() {
        #expect(classify("see https://example.com for details").kind != .bookmark)
    }

    @Test func plainStatementIsANote() {
        let result = classify("Lisbon was lovely")
        #expect(result.kind == .note)
        #expect(result.due == nil)
    }

    @Test func bugAndIdeaPrefixes() {
        #expect(classify("bug: crash on launch").kind == .bug)
        #expect(classify("Bug login button does nothing").kind == .bug)
        #expect(classify("idea: a sticky note for URLs").kind == .idea)
        #expect(classify("bugs are everywhere").kind != .bug)
    }

    @Test func linesOfCheckboxesOrDashesMakeATodoList() {
        #expect(classify("[] milk\n[ ] eggs").kind == .todoList)
        #expect(classify("- [ ] milk\n- [ ] eggs\n- bread").kind == .todoList)
        #expect(classify("- milk\n\n- eggs").kind == .todoList)
    }

    @Test func aSingleItemOrMixedLinesAreNotATodoList() {
        #expect(classify("- milk").kind != .todoList)
        #expect(classify("Groceries\n- milk\n- eggs").kind != .todoList)
    }

    @Test func dateOnlyMakesATaskDueAtNineAM() {
        let result = classify("Dentist on Nov 3")
        #expect(result.kind == .task)
        #expect(result.due == newYorkDate(2026, 11, 3, 9))
        #expect(!result.hasTime)
    }

    @Test func weekdayNameMeansTheNextOne() {
        let result = classify("Dinner Friday at 7:30pm")
        #expect(result.kind == .event)
        #expect(result.due == newYorkDate(2026, 10, 30, 19, 30))
    }

    @Test(arguments: [
        ("Lunch tomorrow at 2", 14), ("Lunch tomorrow at 11", 11), ("Lunch tomorrow at 6", 18),
        ("Lunch tomorrow at 7", 7),
    ])
    func bareHourOneToSixMeansAfternoon(text: String, hour: Int) {
        #expect(classify(text).due == newYorkDate(2026, 10, 26, hour))
    }

    @Test func explicitMeridiemWins() {
        #expect(classify("Lunch tomorrow at 2am").due == newYorkDate(2026, 10, 26, 2))
        #expect(classify("Lunch tomorrow at 14:30").due == newYorkDate(2026, 10, 26, 14, 30))
    }

    @Test func repeatWithADateKeepsTheDate() {
        let result = classify("Pay rent every month starting Nov 1")
        #expect(result.recurrence == RecurrenceRule(frequency: .monthly))
        #expect(result.due == newYorkDate(2026, 11, 1, 9))
    }

    @Test func emptyTextIsANote() {
        #expect(classify("   ").kind == .note)
    }
}
