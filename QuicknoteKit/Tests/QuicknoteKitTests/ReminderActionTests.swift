import Foundation
import Testing

@testable import QuicknoteKit

struct ReminderActionTests {
    private let calendar = ReminderFixtures.calendar
    private let now = ReminderFixtures.date(10, 25, 18)

    @Test func doneOnARepeatingTaskAdvancesItAndHidesItUntilThen() {
        var note = ReminderFixtures.note("Water plants", id: 1, due: ReminderFixtures.date(10, 25, 18))
        note.recurrence = RecurrenceRule(frequency: .daily)
        note.snoozedUntil = ReminderFixtures.date(10, 25, 19)
        let result = ReminderAction.done.apply(to: note, now: now, calendar: calendar)
        #expect(result.completedAt == nil)
        #expect(result.dueAt == ReminderFixtures.date(10, 26, 18))
        #expect(result.snoozedUntil == ReminderFixtures.date(10, 26, 18))
    }

    @Test func doneOnAPlainReminderCompletesIt() {
        let note = ReminderFixtures.note("Dry cleaning", kind: .reminder, id: 2, due: now)
        #expect(ReminderAction.done.apply(to: note, now: now, calendar: calendar).completedAt == now)
    }

    @Test func snoozeOneHourHidesTheNoteForAnHourAndKeepsItOnTheEdge() {
        var note = ReminderFixtures.note("Dry cleaning", kind: .reminder, id: 2, due: now)
        note.onEdge = false
        let result = ReminderAction.snoozeOneHour.apply(to: note, now: now, calendar: calendar)
        #expect(result.snoozedUntil == now.addingTimeInterval(3600))
        #expect(result.onEdge)
        #expect(result.completedAt == nil)
    }

    @Test func actionsAreFoundByTheirNotificationIdentifier() {
        #expect(ReminderAction(rawValue: ReminderAction.done.rawValue) == .done)
        #expect(ReminderAction(rawValue: "com.apple.UNNotificationDefaultActionIdentifier") == nil)
    }
}
