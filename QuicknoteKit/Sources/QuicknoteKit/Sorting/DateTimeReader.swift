import Foundation

struct TimeOfDay: Equatable {
    var hour: Int
    var minute: Int
}

/// Reads the day and time a person typed. NSDataDetector cannot be given "now", so relative words are read here
/// and the detector only handles explicit dates such as "Nov 3".
enum DateTimeReader {
    private static let weekdayNames = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]

    /// Midnight of the day mentioned, or nil.
    static func day(in text: String, now: Date, calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: now)
        return relativeDay(in: text, today: today, calendar: calendar)
            ?? weekday(in: text, today: today, calendar: calendar)
            ?? daysAhead(in: text, today: today, calendar: calendar)
            ?? detectedDay(in: text, today: today, calendar: calendar)
    }

    /// The time mentioned. A bare hour from 1 to 6 means afternoon.
    static func time(in text: String) -> TimeOfDay? {
        if firstCaseInsensitiveMatch(#"\bnoon\b"#, in: text) != nil { return TimeOfDay(hour: 12, minute: 0) }
        let patterns = [
            #"\b(\d{1,2}):(\d{2})\s*([ap]m)?(?![\w:])"#,
            #"\b(\d{1,2})()\s*([ap]m)\b"#,
            #"\bat\s+(\d{1,2})()()\b(?!\s*:)"#,
        ]
        for pattern in patterns {
            guard let found = firstCaseInsensitiveMatch(pattern, in: text) else { continue }
            if let time = timeOfDay(hour: found.captures[0], minute: found.captures[1], meridiem: found.captures[2]) {
                return time
            }
        }
        return nil
    }

    private static func timeOfDay(hour hourText: String, minute minuteText: String, meridiem: String) -> TimeOfDay? {
        guard var hour = Int(hourText), let minute = Int(minuteText.isEmpty ? "0" : minuteText), minute < 60 else {
            return nil
        }
        switch meridiem.lowercased() {
        case "am": guard (1...12).contains(hour) else { return nil }; hour %= 12
        case "pm": guard (1...12).contains(hour) else { return nil }; hour = hour % 12 + 12
        default:
            guard hour < 24 else { return nil }
            if (1...6).contains(hour) { hour += 12 }
        }
        return TimeOfDay(hour: hour, minute: minute)
    }

    // MARK: Days

    private static func relativeDay(in text: String, today: Date, calendar: Calendar) -> Date? {
        guard let found = firstCaseInsensitiveMatch(#"\b(today|tonight|tomorrow)\b"#, in: text) else { return nil }
        let offset = found.captures[0].lowercased() == "tomorrow" ? 1 : 0
        return calendar.date(byAdding: .day, value: offset, to: today)
    }

    /// "Friday" means the next Friday after today, never today.
    private static func weekday(in text: String, today: Date, calendar: Calendar) -> Date? {
        let pattern = "\\b(?:next\\s+|this\\s+)?(\(weekdayNames.joined(separator: "|")))\\b"
        guard let found = firstCaseInsensitiveMatch(pattern, in: text),
            let index = weekdayNames.firstIndex(of: found.captures[0].lowercased())
        else { return nil }
        let daysAway = (index + 1 - calendar.component(.weekday, from: today) + 6) % 7 + 1
        return calendar.date(byAdding: .day, value: daysAway, to: today)
    }

    private static func daysAhead(in text: String, today: Date, calendar: Calendar) -> Date? {
        guard let found = firstCaseInsensitiveMatch(#"\bin\s+(\d+)\s+(day|week)s?\b"#, in: text),
            let count = Int(found.captures[0])
        else { return nil }
        let days = found.captures[1].lowercased() == "week" ? count * 7 : count
        return calendar.date(byAdding: .day, value: days, to: today)
    }

    /// Explicit dates. Without a year the next such date from today is used.
    private static func detectedDay(in text: String, today: Date, calendar: Calendar) -> Date? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        guard let detected = detector?.firstMatch(in: text, range: range)?.date else { return nil }
        let system = Calendar(identifier: .gregorian)
        let parts = system.dateComponents(in: .current, from: detected)
        let hasYear = firstCaseInsensitiveMatch(#"\b\d{4}\b"#, in: text) != nil
        var components = DateComponents(
            year: hasYear ? parts.year : calendar.component(.year, from: today), month: parts.month, day: parts.day)
        guard var day = calendar.date(from: components) else { return nil }
        if !hasYear, day < today {
            components.year = (components.year ?? 0) + 1
            day = calendar.date(from: components) ?? day
        }
        return day
    }
}
