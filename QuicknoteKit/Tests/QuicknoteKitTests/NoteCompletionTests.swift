import Foundation
import Testing

@testable import QuicknoteKit

struct NoteCompletionTests {
    @Test func completingAPlainNoteStampsCompletedAt() {
        let now = newYorkDate(2026, 10, 25, 9)
        let done = Note(body: "Buy milk", kind: .task).completing(now: now, calendar: newYorkCalendar)
        #expect(done.completedAt == now)
    }

    @Test func completingARepeatingNoteMovesTheDueDateInstead() {
        var note = Note(body: "Water plants", kind: .task)
        note.recurrence = RecurrenceRule(frequency: .weekly, weekdays: [3, 5])
        note.dueAt = newYorkDate(2026, 10, 27, 9)
        let done = note.completing(now: newYorkDate(2026, 10, 27, 8), calendar: newYorkCalendar)
        #expect(done.completedAt == nil)
        #expect(done.dueAt == newYorkDate(2026, 10, 29, 9))
    }

    @Test func completingARepeatingNoteHidesItUntilItIsNextDue() {
        var note = Note(body: "Water plants", kind: .task)
        note.recurrence = RecurrenceRule(frequency: .weekly, weekdays: [3, 5])
        note.dueAt = newYorkDate(2026, 10, 27, 9)
        note.snoozedUntil = newYorkDate(2026, 10, 27, 7)
        let done = note.completing(now: newYorkDate(2026, 10, 27, 8), calendar: newYorkCalendar)
        #expect(done.snoozedUntil == newYorkDate(2026, 10, 29, 9))
    }

    @Test func completingAPlainNoteClearsItsSnooze() {
        var note = Note(body: "Buy milk", kind: .task)
        note.snoozedUntil = newYorkDate(2026, 10, 25, 12)
        #expect(note.completing(now: newYorkDate(2026, 10, 25, 9), calendar: newYorkCalendar).snoozedUntil == nil)
    }

    @Test func overdueRepeatSkipsToAnOccurrenceAfterNowKeepingTheTime() {
        var note = Note(body: "Water plants", kind: .task)
        note.recurrence = RecurrenceRule(frequency: .daily)
        note.dueAt = newYorkDate(2026, 10, 20, 9)
        let done = note.completing(now: newYorkDate(2026, 10, 25, 14), calendar: newYorkCalendar)
        #expect(done.dueAt == newYorkDate(2026, 10, 26, 9))
    }

    @Test func weeklyRepeatAcrossTheDSTChangeKeepsNineOClock() {
        var note = Note(body: "Review inbox", kind: .task)
        note.recurrence = RecurrenceRule(frequency: .weekly)
        note.dueAt = newYorkDate(2026, 10, 25, 9)
        let done = note.completing(now: newYorkDate(2026, 10, 25, 9, 30), calendar: newYorkCalendar)
        #expect(done.dueAt == newYorkDate(2026, 11, 1, 9))
        #expect(newYorkCalendar.component(.hour, from: done.dueAt!) == 9)
    }

    @Test func aRepeatWithoutADueDateJustCompletes() {
        var note = Note(body: "Water plants", kind: .task)
        note.recurrence = RecurrenceRule(frequency: .daily)
        let now = newYorkDate(2026, 10, 25, 9)
        #expect(note.completing(now: now, calendar: newYorkCalendar).completedAt == now)
    }
}
