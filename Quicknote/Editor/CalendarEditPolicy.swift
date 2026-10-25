import Foundation
import QuicknoteKit

/// When editing a note should touch its Calendar event. Pure so the rules can be tested.
enum CalendarEditPolicy {
    /// Turning an event with a Calendar copy into another type asks before removing the copy.
    static func asksToRemoveEvent(whenChanging note: Note, to kind: NoteKind) -> Bool {
        note.kind == .event && kind != .event && note.calendarEventId != nil
    }

    /// The event's title, time or repeat changed on a note that already has an event.
    static func updatesEvent(from old: Note, to new: Note) -> Bool {
        guard new.kind == .event, new.calendarEventId != nil else { return false }
        return old.title != new.title || old.dueAt != new.dueAt || old.dueHasTime != new.dueHasTime
            || old.recurrenceJSON != new.recurrenceJSON
    }

    /// A time was just set on an event note that has no Calendar copy yet.
    static func offersEvent(from old: Note, to new: Note) -> Bool {
        guard new.kind == .event, new.calendarEventId == nil, new.dueHasTime, new.dueAt != nil else { return false }
        return !old.dueHasTime || old.dueAt != new.dueAt
    }
}
