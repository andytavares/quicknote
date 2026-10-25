import Foundation
import QuicknoteKit

/// Turns a spoken transcript into a note, and describes it for the HUD.
enum VoiceNote {
    /// A sorted note from the transcript; the caller adds where it was said with `Note.remember(_:)`.
    static func make(text: String, now: Date, calendar: Calendar) -> Note {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var note = Note(body: body, now: now)
        note.apply(EntryClassifier.classify(body, now: now, calendar: calendar))
        return note
    }

    /// "Reminder · Today, 18:00", or just the type when there is no due date.
    static func chip(for note: Note, now: Date, calendar: Calendar) -> String {
        guard let due = note.dueAt else { return note.kind.title }
        let day = dayDescription(due, now: now, calendar: calendar)
        let when = note.dueHasTime ? "\(day), \(due.formatted(clockStyle(calendar)))" : day
        return "\(note.kind.title) · \(when)"
    }

    private static func dayDescription(_ due: Date, now: Date, calendar: Calendar) -> String {
        let day: String
        if calendar.isDate(due, inSameDayAs: now) {
            day = "Today"
        } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
            calendar.isDate(due, inSameDayAs: tomorrow)
        {
            day = "Tomorrow"
        } else {
            day = due.formatted(
                Date.FormatStyle(timeZone: calendar.timeZone).weekday(.abbreviated).day().month(.abbreviated))
        }
        return day
    }

    private static func clockStyle(_ calendar: Calendar) -> Date.VerbatimFormatStyle {
        Date.VerbatimFormatStyle(
            format: "\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)",
            locale: .current, timeZone: calendar.timeZone, calendar: calendar)
    }
}
