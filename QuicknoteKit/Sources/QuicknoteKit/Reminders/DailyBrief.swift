import Foundation

/// A calendar event the app reads from EventKit.
public struct BriefEvent: Equatable, Sendable {
    public var title: String
    public var start: Date
    public var end: Date
    public var isAllDay: Bool
    public var calendarTitle: String
    public var colorHex: String
    public var eventIdentifier: String?

    public init(
        title: String, start: Date, end: Date, isAllDay: Bool, calendarTitle: String, colorHex: String,
        eventIdentifier: String?
    ) {
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.calendarTitle = calendarTitle
        self.colorHex = colorHex
        self.eventIdentifier = eventIdentifier
    }
}

/// The moment the Brief is built for, and the calendar that decides where "today" starts and ends.
public struct BriefDay: Sendable {
    public var now: Date
    public var calendar: Calendar

    public init(now: Date, calendar: Calendar) {
        self.now = now
        self.calendar = calendar
    }

    var interval: DateInterval { calendar.dateInterval(of: .day, for: now)! }
}

/// One note line in the Brief. `time` is nil for untimed items.
public struct BriefItem: Equatable, Sendable {
    public var noteId: Int64?
    public var title: String
    public var kind: NoteKind
    public var time: Date?
    /// The UI strikes completed items through.
    public var isCompleted: Bool

    init(_ note: Note, time: Date?) {
        noteId = note.id
        title = note.title
        kind = note.kind
        self.time = time
        isCompleted = note.completedAt != nil
    }
}

/// Sections in display order: events, due today, overdue, coming back.
public struct DailyBrief: Equatable, Sendable {
    public var date: Date
    public var events: [BriefEvent]
    public var dueToday: [BriefItem]
    public var overdue: [BriefItem]
    public var comingBack: [BriefItem]

    var openDueCount: Int { dueToday.filter { !$0.isCompleted }.count }

    /// For example "2 events, 3 tasks, 1 overdue, 2 notes coming back".
    public var headline: String {
        let parts = [
            count(events.count, "event", "events"),
            count(openDueCount, "task", "tasks"),
            overdue.isEmpty ? nil : "\(overdue.count) overdue",
            count(comingBack.count, "note coming back", "notes coming back"),
        ].compactMap { $0 }
        return parts.isEmpty ? "Nothing planned today" : parts.joined(separator: ", ")
    }

    private func count(_ number: Int, _ singular: String, _ plural: String) -> String? {
        number == 0 ? nil : "\(number) \(number == 1 ? singular : plural)"
    }
}

public enum DailyBriefBuilder {
    public static func build(notes: [Note], events: [BriefEvent], day: BriefDay) -> DailyBrief {
        let today = day.interval
        return DailyBrief(
            date: day.now,
            events: eventsToday(events, in: today),
            dueToday: dueToday(notes, in: today),
            overdue: overdue(notes, before: today.start),
            comingBack: comingBack(notes, day: day, today: today))
    }

    private static func eventsToday(_ events: [BriefEvent], in today: DateInterval) -> [BriefEvent] {
        events
            .filter { $0.start < today.end && ($0.end > today.start || $0.start >= today.start) }
            .sorted { ($0.isAllDay ? 0 : 1, $0.start) < ($1.isAllDay ? 0 : 1, $1.start) }
    }

    private static func dueToday(_ notes: [Note], in today: DateInterval) -> [BriefItem] {
        let due = notes.filter { note in
            guard ReminderPlanner.briefKinds.contains(note.kind), let dueAt = note.dueAt else { return false }
            return today.contains(dueAt) && dueAt < today.end
                && (note.completedAt.map { today.contains($0) } ?? true)
        }
        let items = due.map { BriefItem($0, time: $0.dueHasTime ? $0.dueAt : nil) }
        return items.filter { $0.time != nil }.sorted { $0.time! < $1.time! } + items.filter { $0.time == nil }
    }

    private static func overdue(_ notes: [Note], before start: Date) -> [BriefItem] {
        notes
            .filter {
                ReminderPlanner.briefKinds.contains($0.kind) && $0.completedAt == nil && ($0.dueAt ?? start) < start
            }
            .sorted { $0.dueAt! < $1.dueAt! }
            .map { BriefItem($0, time: $0.dueHasTime ? $0.dueAt : nil) }
    }

    private static func comingBack(_ notes: [Note], day: BriefDay, today: DateInterval) -> [BriefItem] {
        let rest = DateInterval(start: day.now, end: today.end)
        return ReminderPlanner.notesComingBack(notes, between: rest)
            .filter { $0.snoozedUntil! > day.now && $0.snoozedUntil! < today.end }
            .map { BriefItem($0, time: $0.snoozedUntil) }
    }
}
