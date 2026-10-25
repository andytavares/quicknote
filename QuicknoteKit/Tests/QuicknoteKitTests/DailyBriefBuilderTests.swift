import Foundation
import Testing

@testable import QuicknoteKit

struct DailyBriefBuilderTests {
    private let calendar = ReminderFixtures.calendar
    private let day = BriefDay(now: ReminderFixtures.date(10, 25, 8), calendar: ReminderFixtures.calendar)

    private func date(_ hour: Int, _ minute: Int = 0, day: Int = 25) -> Date {
        ReminderFixtures.date(10, day, hour, minute)
    }
    private func note(_ body: String, kind: NoteKind = .task, due: Date?, timed: Bool = true) -> Note {
        ReminderFixtures.note(body, kind: kind, id: 1, due: due, timed: timed)
    }
    private func event(_ title: String, _ start: Date, _ end: Date, allDay: Bool = false) -> BriefEvent {
        BriefEvent(
            title: title, start: start, end: end, isAllDay: allDay, calendarTitle: "Home", colorHex: "#2F6FED",
            eventIdentifier: nil)
    }
    private func build(_ notes: [Note] = [], _ events: [BriefEvent] = []) -> DailyBrief {
        DailyBriefBuilder.build(notes: notes, events: events, day: day)
    }

    @Test func eventsListAllDayFirstThenByStartAndDropOtherDays() {
        let brief = build(
            [],
            [
                event("Call with Mum", date(16, 30), date(17)),
                event("Brunch with Ana", date(10), date(11)),
                event("Holiday", date(0), date(0, day: 26), allDay: true),
                event("Yesterday", date(10, day: 24), date(11, day: 24)),
                event("Tomorrow", date(10, day: 26), date(11, day: 26)),
                event("Ended at midnight", date(0, day: 24), date(0), allDay: true),
            ])
        #expect(brief.events.map(\.title) == ["Holiday", "Brunch with Ana", "Call with Mum"])
    }

    @Test func dueTodayOrdersTimedThenUntimedAndKeepsOnlyTaskLikeKinds() {
        let brief = build([
            note("Untimed", due: date(0), timed: false),
            note("Afternoon", due: date(15)),
            note("Morning", kind: .reminder, due: date(9)),
            note("List", kind: .todoList, due: date(12)),
            note("An idea", kind: .idea, due: date(10)),
            note("Tomorrow", due: date(9, day: 26)),
        ])
        #expect(brief.dueToday.map(\.title) == ["Morning", "List", "Afternoon", "Untimed"])
        #expect(brief.dueToday.map(\.time) == [date(9), date(12), date(15), nil])
    }

    @Test func completedTodayStaysAsCompletedButCompletedEarlierIsDropped() {
        var doneToday = note("Done today", due: date(9))
        doneToday.completedAt = date(7)
        var doneEarlier = note("Done last week", due: date(9))
        doneEarlier.completedAt = date(7, day: 20)
        let brief = build([doneToday, doneEarlier, note("Open", due: date(10))])
        #expect(brief.dueToday.map(\.title) == ["Done today", "Open"])
        #expect(brief.dueToday.map(\.isCompleted) == [true, false])
    }

    @Test func overdueIsOpenBeforeTodayOldestFirst() {
        var doneOverdue = note("Done", due: date(9, day: 20))
        doneOverdue.completedAt = date(7, day: 21)
        let brief = build([
            note("Newer", due: date(9, day: 24)),
            note("Oldest", due: date(9, day: 20), timed: false),
            doneOverdue,
            note("Today", due: date(0), timed: false),
        ])
        #expect(brief.overdue.map(\.title) == ["Oldest", "Newer"])
        #expect(brief.dueToday.map(\.title) == ["Today"])
    }

    @Test func comingBackIsSnoozedLaterTodayByTime() {
        let brief = build([
            note("Evening", kind: .note, due: nil).snoozed(until: date(20)),
            note("Noon", kind: .note, due: nil).snoozed(until: date(12)),
            note("Tomorrow", kind: .note, due: nil).snoozed(until: date(9, day: 26)),
            note("Already back", kind: .note, due: nil).snoozed(until: date(7)),
        ])
        #expect(brief.comingBack.map(\.title) == ["Noon", "Evening"])
    }

    @Test func headlineCountsOpenItemsAndOmitsZeroParts() {
        var done = note("Done", due: date(9))
        done.completedAt = date(7)
        let brief = build(
            [
                note("A", due: date(10)), note("B", due: date(11)), note("C", due: date(12)), done,
                note("Old", due: date(9, day: 20)),
                note("N1", kind: .note, due: nil).snoozed(until: date(14)),
                note("N2", kind: .note, due: nil).snoozed(until: date(15)),
            ],
            [event("Brunch", date(10), date(11)), event("Call", date(16), date(17))])
        #expect(brief.headline == "2 events, 3 tasks, 1 overdue, 2 notes coming back")
    }

    @Test func headlineUsesSingularsAndEmptyDay() {
        #expect(build().headline == "Nothing planned today")
        let single = build(
            [note("Old", due: date(9, day: 20)), note("N", kind: .note, due: nil).snoozed(until: date(14))],
            [event("Brunch", date(10), date(11))])
        #expect(single.headline == "1 event, 1 overdue, 1 note coming back")
    }
}
