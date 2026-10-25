import Foundation
import NaturalLanguage

/// What a capture turned out to be, and what was read from it.
public struct Classification: Equatable, Sendable {
    public var kind: NoteKind
    public var due: Date?
    public var hasTime: Bool
    public var recurrence: RecurrenceRule?

    public init(kind: NoteKind, due: Date? = nil, hasTime: Bool = false, recurrence: RecurrenceRule? = nil) {
        self.kind = kind
        self.due = due
        self.hasTime = hasTime
        self.recurrence = recurrence
    }
}

public enum EntryClassifier {
    public static func classify(_ text: String, now: Date, calendar: Calendar) -> Classification {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let repeatMatch = RecurrenceParser.find(in: trimmed)
        if let kind = kindFromShape(of: trimmed) {
            return Classification(kind: kind, recurrence: repeatMatch?.rule)
        }
        var withoutRepeat = trimmed
        if let repeatMatch { withoutRepeat.removeSubrange(repeatMatch.range) }
        let day = DateTimeReader.day(in: withoutRepeat, now: now, calendar: calendar)
        let time = DateTimeReader.time(in: withoutRepeat)
        var result = classifyByWhen(trimmed, day: day, time: time, now: now, calendar: calendar)
        result.recurrence = repeatMatch?.rule
        if result.recurrence != nil && result.kind == .note { result.kind = .task }
        return result
    }

    // MARK: Rules that look only at how the text is written

    private static func kindFromShape(of text: String) -> NoteKind? {
        let lowercased = text.lowercased()
        if isOnlyURL(text) { return .bookmark }
        if lowercased.hasPrefix("bug:") || lowercased.hasPrefix("bug ") { return .bug }
        if lowercased.hasPrefix("idea:") { return .idea }
        return isTodoList(text) ? .todoList : nil
    }

    private static func isOnlyURL(_ text: String) -> Bool {
        guard !text.contains(where: \.isWhitespace), let url = URL(string: text) else { return false }
        return ["http", "https"].contains(url.scheme?.lowercased()) && url.host != nil
    }

    private static func isTodoList(_ text: String) -> Bool {
        let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        let markers = ["[]", "[ ]", "- [ ]", "- "]
        return lines.count >= 2 && lines.allSatisfy { line in markers.contains { line.hasPrefix($0) } }
    }

    // MARK: Rules that use the date and time

    private static func classifyByWhen(
        _ text: String, day: Date?, time: TimeOfDay?, now: Date, calendar: Calendar
    ) -> Classification {
        if text.lowercased().hasPrefix("remind me") {
            return reminder(day: day, time: time, now: now, calendar: calendar)
        }
        guard let day else { return Classification(kind: startsWithVerb(text) ? .task : .note) }
        guard let time else {
            return Classification(kind: .task, due: at(TimeOfDay(hour: 9, minute: 0), on: day, calendar: calendar))
        }
        return Classification(kind: .event, due: at(time, on: day, calendar: calendar), hasTime: true)
    }

    private static func reminder(day: Date?, time: TimeOfDay?, now: Date, calendar: Calendar) -> Classification {
        switch (day, time) {
        case (nil, nil):
            return Classification(kind: .reminder)
        case (let day?, nil):
            return Classification(kind: .reminder, due: at(TimeOfDay(hour: 9, minute: 0), on: day, calendar: calendar))
        case (let day?, let time?):
            return Classification(kind: .reminder, due: at(time, on: day, calendar: calendar), hasTime: true)
        case (nil, let time?):
            let today = at(time, on: calendar.startOfDay(for: now), calendar: calendar)
            let due = today > now ? today : calendar.date(byAdding: .day, value: 1, to: today)
            return Classification(kind: .reminder, due: due, hasTime: true)
        }
    }

    private static func at(_ time: TimeOfDay, on day: Date, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: day) ?? day
    }

    private static func startsWithVerb(_ text: String) -> Bool {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        var isVerb = false
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass,
            options: [.omitWhitespace, .omitPunctuation]
        ) { tag, _ in
            isVerb = tag == .verb
            return false
        }
        return isVerb
    }
}
