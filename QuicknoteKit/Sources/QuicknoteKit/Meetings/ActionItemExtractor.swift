import Foundation

public struct ActionItem: Equatable, Sendable {
    public var text: String
    public var atMs: Int
    public var due: Date?

    public init(text: String, atMs: Int, due: Date?) {
        self.text = text
        self.atMs = atMs
        self.due = due
    }
}

/// Finds commitments in a transcript by phrase matching. No model involved.
public enum ActionItemExtractor {
    private static let phrases = [
        "action item", "to-do", "todo", "i'll ", "i will ", "we need to", "can you ", "let's make sure",
    ]
    private static let weekdays = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
    private static let namedWill = "\\b(?!(?:It|This|That|There|What|Who|Which) )[A-Z][a-z]+ will "

    public static func actionItems(in segments: [TranscriptSegment], now: Date) -> [ActionItem] {
        var found: [ActionItem] = []
        var seen = Set<String>()
        for segment in segments {
            for sentence in sentences(of: segment.text) where isActionItem(sentence) {
                let text = cleaned(sentence)
                guard seen.insert(comparisonKey(text)).inserted else { continue }
                found.append(ActionItem(text: text, atMs: segment.startMs, due: dueDate(in: text, now: now)))
            }
        }
        return found
    }

    static func sentences(of text: String) -> [String] {
        var result: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) { sentence, _, _, _ in
            if let sentence { result.append(sentence) }
        }
        return result
    }

    static func isActionItem(_ sentence: String) -> Bool {
        let lowered = sentence.lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
        return phrases.contains { lowered.contains($0) }
            || sentence.range(of: namedWill, options: .regularExpression) != nil
    }

    private static func cleaned(_ sentence: String) -> String {
        var text = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        if let prefix = text.range(of: "action item:", options: [.anchored, .caseInsensitive]) {
            text.removeSubrange(prefix)
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    private static func comparisonKey(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    /// Weekday names, "tomorrow" and "next week", as the start of that day after `now`.
    /// NSDataDetector has no reference-date parameter, so it cannot resolve these against `now`.
    static func dueDate(in text: String, now: Date) -> Date? {
        let calendar = Calendar.current
        let lowered = text.lowercased()
        let today = calendar.startOfDay(for: now)
        if lowered.contains("tomorrow") { return calendar.date(byAdding: .day, value: 1, to: today) }
        if lowered.contains("next week") { return calendar.date(byAdding: .day, value: 7, to: today) }
        guard let index = weekdays.firstIndex(where: { lowered.contains($0) }) else { return nil }
        return calendar.nextDate(
            after: now, matching: DateComponents(hour: 0, weekday: index + 1), matchingPolicy: .nextTime)
    }
}
