import AppKit
import EventKit
import Foundation
import QuicknoteKit

/// The Calendar event fields derived from a note. Pure, so the mapping can be tested without Calendar access.
struct EventDraft: Equatable {
    var title: String
    var notes: String
    var url: URL?
    var start: Date
    var end: Date
    var isAllDay: Bool
    var recurrence: RecurrenceRule?

    /// Nil when the note has no due date. A date without a time becomes an all-day event.
    init?(note: Note, duration: TimeInterval) {
        guard let dueAt = note.dueAt else { return nil }
        title = note.title
        notes = note.body
        url = note.url.flatMap(URL.init(string:))
        start = dueAt
        isAllDay = !note.dueHasTime
        end = isAllDay ? dueAt : dueAt.addingTimeInterval(duration)
        recurrence = note.recurrence
    }

    func apply(to event: EKEvent) {
        event.title = title
        event.notes = notes
        event.url = url
        event.startDate = start
        event.endDate = end
        event.isAllDay = isAllDay
        event.recurrenceRules = recurrence.map { [$0.eventKitRule] }
    }
}

extension RecurrenceRule {
    var eventKitRule: EKRecurrenceRule {
        let weekdays = weekdays.sorted().compactMap(EKWeekday.init(rawValue:)).map {
            EKRecurrenceDayOfWeek($0)
        }
        return EKRecurrenceRule(
            recurrenceWith: frequency.eventKitFrequency, interval: interval,
            daysOfTheWeek: frequency == .weekly && !weekdays.isEmpty ? weekdays : nil,
            daysOfTheMonth: nil, monthsOfTheYear: nil, weeksOfTheYear: nil, daysOfTheYear: nil,
            setPositions: nil, end: nil)
    }
}

extension RecurrenceRule.Frequency {
    fileprivate var eventKitFrequency: EKRecurrenceFrequency {
        switch self {
        case .daily: .daily
        case .weekly: .weekly
        case .monthly: .monthly
        case .yearly: .yearly
        }
    }
}

extension BriefEvent {
    init(event: EKEvent) {
        self.init(
            title: event.title ?? "", start: event.startDate, end: event.endDate, isAllDay: event.isAllDay,
            calendarTitle: event.calendar?.title ?? "", colorHex: event.calendar?.hexColor ?? "#888888",
            eventIdentifier: event.eventIdentifier)
    }
}

extension EKCalendar {
    var hexColor: String {
        guard let color = NSColor(cgColor: cgColor)?.usingColorSpace(.sRGB) else { return "#888888" }
        let channels = [color.redComponent, color.greenComponent, color.blueComponent]
        return "#" + channels.map { String(format: "%02X", Int(($0 * 255).rounded())) }.joined()
    }
}

/// Keeps a note and its Calendar event agreeing after the event changed in Calendar.
enum EventSyncRule {
    /// The note with its due date moved to the event, or its event link cleared when `eventStart` is nil
    /// (the event was deleted). Nil when nothing changes.
    static func reconciled(_ note: Note, eventStart: Date?) -> Note? {
        var result = note
        guard let eventStart else {
            result.calendarEventId = nil
            return result
        }
        guard note.dueAt.map({ abs($0.timeIntervalSince(eventStart)) >= 1 }) ?? true else { return nil }
        result.dueAt = eventStart
        return result
    }
}
