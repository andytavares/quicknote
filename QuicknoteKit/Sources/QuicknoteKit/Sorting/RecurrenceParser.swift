import Foundation

/// A repeat phrase found in text, with where it sits so the title can drop it.
public struct RecurrenceMatch: Equatable, Sendable {
    public var rule: RecurrenceRule
    public var range: Range<String.Index>
}

public enum RecurrenceParser {
    public static func parse(_ text: String) -> RecurrenceRule? {
        find(in: text)?.rule
    }

    /// Finds the first repeat phrase, such as "every tue and thu" in "water plants every tue and thu".
    public static func find(in text: String) -> RecurrenceMatch? {
        findWeekdayList(in: text) ?? findEveryUnit(in: text) ?? findAdverb(in: text)
    }

    public static func describe(_ rule: RecurrenceRule) -> String {
        let every =
            rule.interval == 1
            ? "Every \(unitName(rule.frequency))" : "Every \(rule.interval) \(unitName(rule.frequency))s"
        guard rule.frequency == .weekly, !rule.weekdays.isEmpty else { return every }
        if rule.interval == 1 && rule.weekdays == workdays { return "Every weekday" }
        let names = joined(rule.weekdays.sorted().map { dayNames[$0 - 1] })
        return rule.interval == 1 ? "Weekly on \(names)" : "\(every) on \(names)"
    }

    // MARK: Matching

    private static let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    private static let workdays: Set<Int> = [2, 3, 4, 5, 6]
    private static let dayPattern =
        "(?:mon(?:day)?|tue(?:s(?:day)?)?|wed(?:nesday)?|thu(?:r(?:s(?:day)?)?)?|fri(?:day)?|sat(?:urday)?|sun(?:day)?)"

    private static func findWeekdayList(in text: String) -> RecurrenceMatch? {
        if let weekday = firstCaseInsensitiveMatch(#"\bevery\s+weekdays?\b"#, in: text) {
            return RecurrenceMatch(rule: RecurrenceRule(frequency: .weekly, weekdays: workdays), range: weekday.range)
        }
        let pattern = #"\bevery\s+(\#(dayPattern)(?:\s*(?:,|&|and)\s*\#(dayPattern))*)\b"#
        guard let found = firstCaseInsensitiveMatch(pattern, in: text), let list = found.captures.first else {
            return nil
        }
        let words = list.lowercased().matches(of: /[a-z]+/).map { String($0.output) }.filter { $0 != "and" }
        let numbers = Set(
            words.compactMap { word in dayNames.firstIndex { $0.lowercased().hasPrefix(word.prefix(3)) } }.map {
                $0 + 1
            })
        return RecurrenceMatch(rule: RecurrenceRule(frequency: .weekly, weekdays: numbers), range: found.range)
    }

    private static func findEveryUnit(in text: String) -> RecurrenceMatch? {
        guard
            let found = firstCaseInsensitiveMatch(#"\bevery\s+(?:(other|\d+)\s+)?(day|week|month|year)s?\b"#, in: text)
        else { return nil }
        let step = found.captures[0].lowercased()
        let interval = step == "other" ? 2 : Int(step) ?? 1
        guard let frequency = frequency(forUnit: found.captures[1].lowercased()) else { return nil }
        return RecurrenceMatch(rule: RecurrenceRule(frequency: frequency, interval: interval), range: found.range)
    }

    private static func findAdverb(in text: String) -> RecurrenceMatch? {
        guard let found = firstCaseInsensitiveMatch(#"\b(daily|weekly|monthly|yearly|annually)\b"#, in: text) else {
            return nil
        }
        let frequency: RecurrenceRule.Frequency =
            switch found.captures[0].lowercased() {
            case "daily": .daily
            case "weekly": .weekly
            case "monthly": .monthly
            default: .yearly
            }
        return RecurrenceMatch(rule: RecurrenceRule(frequency: frequency), range: found.range)
    }

    // MARK: Wording

    private static func frequency(forUnit unit: String) -> RecurrenceRule.Frequency? {
        ["day": .daily, "week": .weekly, "month": .monthly, "year": .yearly][unit]
    }

    private static func unitName(_ frequency: RecurrenceRule.Frequency) -> String {
        switch frequency {
        case .daily: "day"
        case .weekly: "week"
        case .monthly: "month"
        case .yearly: "year"
        }
    }

    private static func joined(_ names: [String]) -> String {
        guard let last = names.last, names.count > 1 else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " and " + last
    }
}
