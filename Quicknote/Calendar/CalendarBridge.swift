import AppKit
import EventKit
import Foundation
import QuicknoteKit

/// Everything Quicknote does with Calendar (EventKit, full access). One shared instance.
@MainActor
final class CalendarBridge {
    static let shared = CalendarBridge()
    static let defaultDuration: TimeInterval = 30 * 60

    private let store = EKEventStore()
    private var observer: (any NSObjectProtocol)?
    private let defaults = UserDefaults.standard
    private static let lastCalendarKey = "calendar.lastCalendarIdentifier"

    private var notes: NoteRepository { NoteRepository(database: AppEnvironment.current.database) }

    /// Asks for full access when needed (S03 explainer, then the system prompt). True when events can be read and written.
    func ensureAccess() async -> Bool {
        guard await Permissions.ensure(.calendar) else { return false }
        if EKEventStore.authorizationStatus(for: .event) == .notDetermined {
            _ = try? await store.requestFullAccessToEvents()
        }
        let allowed = EKEventStore.authorizationStatus(for: .event) == .fullAccess
        if allowed { startSyncingFromCalendar() }
        return allowed
    }

    /// Writable event calendars, including Google and Outlook accounts synced into Calendar.
    func writableCalendars() -> [EKCalendar] {
        store.calendars(for: .event).filter(\.allowsContentModifications)
    }

    /// The calendar chosen last time, else the system default for new events, else the first writable one.
    func preferredCalendar() -> EKCalendar? {
        let remembered = defaults.string(forKey: Self.lastCalendarKey).flatMap(store.calendar(withIdentifier:))
        return remembered ?? store.defaultCalendarForNewEvents ?? writableCalendars().first
    }

    /// Creates the note's event, or updates it when `note.calendarEventId` still points at one.
    /// The note's due date follows the draft. Returns the saved note.
    func saveEvent(_ draft: EventDraft, for note: Note, in calendar: EKCalendar) throws -> Note {
        let event = note.calendarEventId.flatMap(store.event(withIdentifier:)) ?? EKEvent(eventStore: store)
        draft.apply(to: event)
        event.calendar = calendar
        try store.save(event, span: .futureEvents)
        defaults.set(calendar.calendarIdentifier, forKey: Self.lastCalendarKey)
        var saved = note
        saved.calendarEventId = event.eventIdentifier
        saved.dueAt = draft.start
        try notes.save(&saved, now: Date())
        return saved
    }

    /// Pushes a note's edits to its existing event, keeping the event's calendar and length. No-op without an event.
    func updateEvent(for note: Note) throws {
        guard let event = note.calendarEventId.flatMap(store.event(withIdentifier:)),
            let calendar = event.calendar
        else { return }
        let length = event.endDate.timeIntervalSince(event.startDate)
        guard let draft = EventDraft(note: note, duration: length) else { return }
        _ = try saveEvent(draft, for: note, in: calendar)
    }

    /// Deletes the note's event (all repeats) and clears the link. The note stays.
    func deleteEvent(for note: Note) throws -> Note {
        if let event = note.calendarEventId.flatMap(store.event(withIdentifier:)) {
            try store.remove(event, span: .futureEvents)
        }
        var saved = note
        saved.calendarEventId = nil
        try notes.save(&saved, now: Date())
        return saved
    }

    func eventsToday(now: Date = Date(), calendar: Calendar = .current) -> [BriefEvent] {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess,
            let today = calendar.dateInterval(of: .day, for: now)
        else { return [] }
        let predicate = store.predicateForEvents(withStart: today.start, end: today.end, calendars: nil)
        return store.events(matching: predicate).map(BriefEvent.init(event:))
    }

    /// Listens for Calendar changes and applies them to notes. Safe to call more than once.
    /// At launch: catch up on Calendar edits made while Quicknote was closed. Never asks for access.
    func resumeSyncingIfAllowed() {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return }
        syncNotesFromCalendar()
        startSyncingFromCalendar()
    }

    func startSyncingFromCalendar() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.syncNotesFromCalendar() }
        }
    }

    private func syncNotesFromCalendar() {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess,
            let openNotes = try? notes.notes(matching: .inbox)
        else { return }
        for note in openNotes where note.calendarEventId != nil {
            let eventStart = note.calendarEventId.flatMap(store.event(withIdentifier:))?.startDate
            guard var changed = EventSyncRule.reconciled(note, eventStart: eventStart) else { continue }
            try? notes.save(&changed, now: Date())
        }
    }
}
