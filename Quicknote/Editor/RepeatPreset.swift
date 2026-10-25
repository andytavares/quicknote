import Foundation
import QuicknoteKit

/// The presets in the Repeat picker (S13).
enum RepeatPreset: CaseIterable, Identifiable {
    case never, daily, weekday, weekly, biweekly, monthly, yearly

    var id: Self { self }

    var title: String {
        switch self {
        case .never: "Never"
        case .daily: "Every day"
        case .weekday: "Every weekday"
        case .weekly: "Every week"
        case .biweekly: "Every 2 weeks"
        case .monthly: "Every month"
        case .yearly: "Every year"
        }
    }

    var rule: RecurrenceRule? {
        switch self {
        case .never: nil
        case .daily: RecurrenceRule(frequency: .daily)
        case .weekday: RecurrenceRule(frequency: .weekly, weekdays: [2, 3, 4, 5, 6])
        case .weekly: RecurrenceRule(frequency: .weekly)
        case .biweekly: RecurrenceRule(frequency: .weekly, interval: 2)
        case .monthly: RecurrenceRule(frequency: .monthly)
        case .yearly: RecurrenceRule(frequency: .yearly)
        }
    }
}

/// What the picker reads back for typed text: the rule, in words, with its next dates.
struct RepeatPreview: Equatable {
    var rule: RecurrenceRule
    var description: String
    var nextDates: [Date]

    static func make(from text: String, after start: Date, calendar: Calendar) -> RepeatPreview? {
        guard let rule = RecurrenceParser.parse(text) else { return nil }
        var dates: [Date] = []
        var cursor = start
        for _ in 0..<3 {
            cursor = rule.nextOccurrence(after: cursor, calendar: calendar)
            dates.append(cursor)
        }
        return RepeatPreview(rule: rule, description: RecurrenceParser.describe(rule), nextDates: dates)
    }
}
