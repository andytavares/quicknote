import Foundation

/// One choice in the snooze menu.
public struct SnoozeOption: Equatable, Sendable {
    public var title: String
    public var until: Date

    public init(title: String, until: Date) {
        self.title = title
        self.until = until
    }

    /// "This evening" is offered only before 19:00; "Next week" is always a later Monday.
    public static func options(now: Date, calendar: Calendar) -> [SnoozeOption] {
        let startOfToday = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        var options = [
            SnoozeOption(title: "15 minutes", until: now.addingTimeInterval(15 * 60)),
            SnoozeOption(title: "1 hour", until: now.addingTimeInterval(60 * 60)),
        ]
        if let evening = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now),
            calendar.component(.hour, from: now) < 19
        {
            options.append(SnoozeOption(title: "This evening", until: evening))
        }
        options.append(SnoozeOption(title: "Tomorrow morning", until: morning(of: tomorrow, calendar)))
        options.append(SnoozeOption(title: "Next week", until: nextMondayMorning(after: tomorrow, calendar)))
        return options
    }

    private static func morning(of day: Date, _ calendar: Calendar) -> Date {
        calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day)!
    }

    /// `day` is the start of tomorrow, so a Monday today is skipped.
    private static func nextMondayMorning(after day: Date, _ calendar: Calendar) -> Date {
        let monday = DateComponents(hour: 9, minute: 0, weekday: 2)
        return calendar.nextDate(after: day.addingTimeInterval(-1), matching: monday, matchingPolicy: .nextTime)!
    }
}

extension Note {
    /// Hides the note until `until` and puts it back on the edge when it returns.
    public func snoozed(until: Date) -> Note {
        var note = self
        note.snoozedUntil = until
        note.onEdge = true
        return note
    }
}
