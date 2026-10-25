import AppKit
import EventKit
import QuicknoteKit
import SwiftUI

/// "Add to Calendar?" panel (S06). Nothing is written to Calendar until "Add event" is pressed.
enum CalendarConfirmation {
    private static var panel: NSPanel?

    /// Asks before writing the note's event to Calendar. Does nothing for notes without a due time.
    static func present(forNoteId noteId: Int64) {
        let repository = NoteRepository(database: AppEnvironment.current.database)
        guard let note = try? repository.note(id: noteId), note.dueAt != nil, note.dueHasTime else { return }
        Task {
            guard await CalendarBridge.shared.ensureAccess() else { return }
            show(note)
        }
    }

    private static func show(_ note: Note) {
        let calendars = CalendarBridge.shared.writableCalendars()
        guard let draft = EventDraft(note: note, duration: CalendarBridge.defaultDuration),
            let first = CalendarBridge.shared.preferredCalendar() ?? calendars.first
        else { return }
        let model = ConfirmationModel(note: note, draft: draft, calendars: calendars, selected: first)
        model.onFinish = { close() }
        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 220),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel], backing: .buffered, defer: false)
        newPanel.title = "Add to Calendar?"
        newPanel.isFloatingPanel = true
        newPanel.titleVisibility = .hidden
        newPanel.titlebarAppearsTransparent = true
        newPanel.contentView = NSHostingView(rootView: CalendarConfirmationView(model: model))
        newPanel.center()
        panel?.close()
        panel = newPanel
        newPanel.makeKeyAndOrderFront(nil)
    }

    private static func close() {
        panel?.close()
        panel = nil
    }
}

@Observable
final class ConfirmationModel {
    static let durationsInMinutes = [15, 30, 45, 60, 90, 120]

    let note: Note
    let calendars: [EKCalendar]
    var title: String
    var start: Date
    var durationInMinutes = 30
    var selected: EKCalendar
    var onFinish: () -> Void = {}
    var errorMessage: String?
    private let draft: EventDraft

    init(note: Note, draft: EventDraft, calendars: [EKCalendar], selected: EKCalendar) {
        self.note = note
        self.draft = draft
        self.calendars = calendars
        self.selected = selected
        title = draft.title
        start = draft.start
    }

    func addEvent() {
        var edited = draft
        edited.title = title
        edited.start = start
        edited.end = start.addingTimeInterval(TimeInterval(durationInMinutes * 60))
        do {
            _ = try CalendarBridge.shared.saveEvent(edited, for: note, in: selected)
            onFinish()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CalendarConfirmationView: View {
    @Bindable var model: ConfirmationModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add to Calendar?").font(.headline)
            TextField("Title", text: $model.title)
                .accessibilityLabel("Event title")
            HStack {
                DatePicker("Date", selection: $model.start, displayedComponents: .date)
                    .labelsHidden().accessibilityLabel("Event date")
                DatePicker("Time", selection: $model.start, displayedComponents: .hourAndMinute)
                    .labelsHidden().accessibilityLabel("Event time")
                Picker("Duration", selection: $model.durationInMinutes) {
                    ForEach(ConfirmationModel.durationsInMinutes, id: \.self) { Text("\($0) min").tag($0) }
                }
                .labelsHidden().accessibilityLabel("Event duration")
            }
            Picker("Calendar", selection: $model.selected) {
                ForEach(model.calendars, id: \.calendarIdentifier) { calendar in
                    Label(calendar.title, systemImage: "circle.fill")
                        .foregroundStyle(Color(cgColor: calendar.cgColor)).tag(calendar)
                }
            }
            .accessibilityLabel("Calendar")
            if let message = model.errorMessage {
                Text(message).font(.caption).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Keep as note only") { model.onFinish() }
                    .accessibilityLabel("Keep as note only")
                    .keyboardShortcut(.cancelAction)
                Button("Add event") { model.addEvent() }
                    .accessibilityLabel("Add event")
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 380)
    }
}
