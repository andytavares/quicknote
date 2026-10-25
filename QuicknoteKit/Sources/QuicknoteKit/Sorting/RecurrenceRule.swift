import Foundation

/// How a note repeats. Weekdays use Gregorian numbering: 1 is Sunday, 7 is Saturday.
public struct RecurrenceRule: Codable, Equatable, Sendable {
    public enum Frequency: String, Codable, Sendable {
        case daily, weekly, monthly, yearly
    }

    public var frequency: Frequency
    public var interval: Int
    /// Only used by weekly rules. Empty means the weekday of the start date.
    public var weekdays: Set<Int>

    public init(frequency: Frequency, interval: Int = 1, weekdays: Set<Int> = []) {
        self.frequency = frequency
        self.interval = max(1, interval)
        self.weekdays = weekdays
    }

    /// The next date in the series. Uses calendar math so the wall-clock time survives DST changes.
    public func nextOccurrence(after date: Date, calendar: Calendar) -> Date {
        switch frequency {
        case .daily: return calendar.date(byAdding: .day, value: interval, to: date)!
        case .weekly: return nextWeekly(after: date, calendar: calendar)
        case .monthly: return calendar.date(byAdding: .month, value: interval, to: date)!
        case .yearly: return calendar.date(byAdding: .year, value: interval, to: date)!
        }
    }

    private func nextWeekly(after date: Date, calendar: Calendar) -> Date {
        let today = calendar.component(.weekday, from: date)
        let days = weekdays.sorted()
        let dayOffset: Int
        if days.isEmpty {
            dayOffset = 7 * interval
        } else if let laterThisWeek = days.first(where: { $0 > today }) {
            dayOffset = laterThisWeek - today
        } else {
            dayOffset = days[0] - today + 7 * interval
        }
        return calendar.date(byAdding: .day, value: dayOffset, to: date)!
    }
}

extension Note {
    /// The repeat rule stored in `recurrenceJSON`. Unreadable JSON reads as no repeat.
    public var recurrence: RecurrenceRule? {
        get {
            recurrenceJSON.flatMap { $0.data(using: .utf8) }.flatMap {
                try? JSONDecoder().decode(RecurrenceRule.self, from: $0)
            }
        }
        set {
            recurrenceJSON = newValue.flatMap { try? JSONEncoder().encode($0) }.flatMap {
                String(data: $0, encoding: .utf8)
            }
        }
    }

    /// Completes a plain note, or moves a repeating note's due date to its next occurrence after `now`.
    public func completing(now: Date, calendar: Calendar) -> Note {
        var result = self
        result.updatedAt = now
        guard let rule = recurrence, let dueAt else {
            result.completedAt = now
            return result
        }
        var next = rule.nextOccurrence(after: dueAt, calendar: calendar)
        while next <= now { next = rule.nextOccurrence(after: next, calendar: calendar) }
        result.dueAt = next
        return result
    }
}
