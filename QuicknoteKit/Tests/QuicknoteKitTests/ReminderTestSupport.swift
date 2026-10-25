import Foundation

@testable import QuicknoteKit

enum ReminderFixtures {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }()

    static func date(_ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    static func note(
        _ body: String, kind: NoteKind = .task, id: Int64? = nil, due: Date? = nil, timed: Bool = true
    ) -> Note {
        var note = Note(body: body, kind: kind, now: date(10, 1))
        note.id = id
        note.dueAt = due
        note.dueHasTime = timed
        return note
    }
}
