import Foundation
import Testing

@testable import QuicknoteKit

struct ReminderPlannerTests {
    private let now = ReminderFixtures.date(10, 25, 9)
    private func date(_ hour: Int, day: Int = 25) -> Date { ReminderFixtures.date(10, day, hour) }
    private func note(_ body: String, kind: NoteKind = .task, id: Int64? = 1, due: Date? = nil, timed: Bool = true)
        -> Note
    {
        ReminderFixtures.note(body, kind: kind, id: id, due: due, timed: timed)
    }

    @Test func alertsForTimedFutureDueSortedByTime() {
        let alerts = ReminderPlanner.plannedAlerts(
            for: [note("Later", id: 1, due: date(15)), note("Sooner", kind: .reminder, id: 2, due: date(11))],
            now: now)
        #expect(alerts.map(\.noteId) == [2, 1])
        #expect(alerts.map(\.title) == ["Sooner", "Later"])
        #expect(alerts.map(\.fireAt) == [date(11), date(15)])
    }

    @Test func skipsUntimedPastCompletedIdlessAndOtherKinds() {
        var completed = note("Done", id: 3, due: date(15))
        completed.completedAt = date(8)
        let skipped = [
            note("Untimed", id: 1, due: date(15), timed: false),
            note("Past", id: 2, due: date(8)),
            completed,
            note("No id", id: nil, due: date(15)),
            note("A plain note", kind: .note, id: 4, due: date(15)),
            note("Exactly now", id: 5, due: now),
        ]
        #expect(ReminderPlanner.plannedAlerts(for: skipped, now: now).isEmpty)
    }

    @Test func snoozeFiresAtSnoozeEndAndWinsOverDue() {
        let snoozed = note("Call bank", id: 1, due: date(10)).snoozed(until: date(13))
        let alerts = ReminderPlanner.plannedAlerts(for: [snoozed], now: now)
        #expect(alerts.map(\.fireAt) == [date(13)])
    }

    @Test func pastSnoozeFallsBackToFutureDue() {
        let expired = note("Call bank", id: 1, due: date(10)).snoozed(until: date(8))
        #expect(ReminderPlanner.plannedAlerts(for: [expired], now: now).map(\.fireAt) == [date(10)])
    }

    @Test func plainNoteWithSnoozeStillAlerts() {
        let snoozed = note("Idea", kind: .idea, id: 1).snoozed(until: date(13))
        #expect(ReminderPlanner.plannedAlerts(for: [snoozed], now: now).count == 1)
    }

    @Test func notesComingBackFiltersByIntervalOpenOnlyAndSorts() {
        var done = note("Done", id: 3).snoozed(until: date(12))
        done.completedAt = date(8)
        let notes = [
            note("B", id: 1).snoozed(until: date(14)),
            note("A", id: 2).snoozed(until: date(11)),
            note("Tomorrow", id: 4).snoozed(until: date(9, day: 26)),
            note("Never snoozed", id: 5),
            done,
        ]
        let interval = DateInterval(start: now, end: date(23))
        #expect(ReminderPlanner.notesComingBack(notes, between: interval).map(\.body) == ["A", "B"])
    }
}
