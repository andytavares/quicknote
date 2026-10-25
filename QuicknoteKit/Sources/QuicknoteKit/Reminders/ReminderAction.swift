import Foundation

/// What a notification button does to its note. The raw value is the notification action identifier.
public enum ReminderAction: String, Sendable {
    case done = "app.quicknote.reminder.done"
    case snoozeOneHour = "app.quicknote.reminder.snooze"

    public func apply(to note: Note, now: Date, calendar: Calendar) -> Note {
        switch self {
        case .done:
            return note.completing(now: now, calendar: calendar)
        case .snoozeOneHour:
            return note.snoozed(until: now.addingTimeInterval(60 * 60))
        }
    }
}
