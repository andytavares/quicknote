import Foundation
import QuicknoteKit

/// Turns a spoken transcript into a note, and describes it for the HUD.
enum VoiceNote {
    static func make(text: String, context: CapturedContext?, now: Date, calendar: Calendar) -> Note {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let classification = EntryClassifier.classify(body, now: now, calendar: calendar)
        var note = Note(body: body, kind: classification.kind, now: now)
        note.dueAt = classification.due
        note.dueHasTime = classification.hasTime
        note.recurrence = classification.recurrence
        note.appBundleId = context?.appBundleId
        note.appName = context?.appName
        note.siteHost = context?.siteHost
        note.url = context?.url
        return note
    }

    /// "Reminder · Today, 18:00", or just the type when there is no due date.
    static func chip(for note: Note, now: Date, calendar: Calendar) -> String {
        guard let due = note.dueAt else { return note.kind.title }
        return
            "\(note.kind.title) · \(dueDescription(due, hasTime: note.dueHasTime, now: now, calendar: calendar))"
    }

    private static func dueDescription(_ due: Date, hasTime: Bool, now: Date, calendar: Calendar) -> String {
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
        return hasTime ? "\(day), \(due.formatted(clockStyle(calendar)))" : day
    }

    private static func clockStyle(_ calendar: Calendar) -> Date.VerbatimFormatStyle {
        Date.VerbatimFormatStyle(
            format: "\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)",
            locale: .current, timeZone: calendar.timeZone, calendar: calendar)
    }
}
