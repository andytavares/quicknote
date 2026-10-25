import AppKit
import Observation
import QuicknoteKit

/// A `[[` completion the text view should apply: replace `range` with `text`.
struct LinkCompletion: Equatable {
    var range: NSRange
    var text: String
}

/// State and saving for one open note. Views read it; the text view and toolbar write through it.
@Observable
final class NoteEditorModel {
    let noteId: Int64
    private(set) var note: Note?
    private(set) var attachments: [Attachment] = []
    private(set) var backlinks: [Note] = []
    private(set) var meeting: Meeting?
    private(set) var linkTrigger: LinkTrigger?
    private(set) var suggestions: [Note] = []
    var selectedSuggestion = 0
    var completionRequest: LinkCompletion?
    /// The kind the person asked for while an event with a Calendar copy waits for "Also remove from Calendar?".
    var kindAwaitingRemovalAnswer: NoteKind?
    var isConfirmingDelete = false
    var errorMessage: String?

    @ObservationIgnored private var savedNote: Note?
    @ObservationIgnored private var debouncer: SaveDebouncer!
    @ObservationIgnored private let database: AppDatabase
    @ObservationIgnored private let repository: NoteRepository
    @ObservationIgnored private let attachmentStore: AttachmentStore
    @ObservationIgnored private let meetings: MeetingRepository

    init(noteId: Int64, environment: AppEnvironment = .current) {
        self.noteId = noteId
        database = environment.database
        repository = NoteRepository(database: environment.database)
        attachmentStore = AttachmentStore(paths: environment.paths, database: environment.database)
        meetings = MeetingRepository(database: environment.database)
        debouncer = SaveDebouncer { [weak self] in self?.save() }
        note = try? repository.note(id: noteId)
        savedNote = note
        reloadFooter()
    }

    var showsCreateRow: Bool { !(linkTrigger?.query.isEmpty ?? true) }
    var suggestionRowCount: Int { linkTrigger == nil ? 0 : suggestions.count + (showsCreateRow ? 1 : 0) }

    // MARK: Saving

    func edit(body: String) {
        note?.body = body
        debouncer.schedule()
    }

    func flush() { debouncer.flush() }

    /// Applies a toolbar change and saves it straight away.
    func update(_ change: (inout Note) -> Void) {
        guard note != nil else { return }
        change(&note!)
        save()
    }

    private func save() {
        guard var current = note, current != savedNote else { return }
        do { try repository.save(&current, now: Date()) } catch { return report(error) }
        let previous = savedNote ?? current
        note = current
        savedNote = current
        syncCalendar(from: previous, to: current)
        reloadFooter()
    }

    private func syncCalendar(from old: Note, to new: Note) {
        if CalendarEditPolicy.updatesEvent(from: old, to: new) {
            do { try CalendarBridge.shared.updateEvent(for: new) } catch { report(error) }
        } else if CalendarEditPolicy.offersEvent(from: old, to: new), let id = new.id {
            CalendarConfirmation.present(forNoteId: id)
        }
    }

    private func report(_ error: Error) { errorMessage = error.localizedDescription }

    // MARK: Type, delete and Calendar questions

    func changeKind(to kind: NoteKind) {
        guard let note, note.kind != kind else { return }
        if CalendarEditPolicy.asksToRemoveEvent(whenChanging: note, to: kind) {
            kindAwaitingRemovalAnswer = kind
        } else {
            update { $0.kind = kind }
        }
    }

    func answerRemoveFromCalendar(_ remove: Bool) {
        guard let kind = kindAwaitingRemovalAnswer else { return }
        kindAwaitingRemovalAnswer = nil
        if remove { removeCalendarEvent() }
        update { $0.kind = kind }
    }

    func deleteNote(removingEvent: Bool) {
        if removingEvent { removeCalendarEvent() }
        do { try repository.delete(noteId: noteId) } catch { return report(error) }
        note = nil
        savedNote = nil
    }

    private func removeCalendarEvent() {
        guard let current = note else { return }
        do {
            note = try CalendarBridge.shared.deleteEvent(for: current)
            savedNote = note
        } catch { report(error) }
    }

    // MARK: Text interactions

    func toggleCheckbox(line: Int) {
        guard let body = note?.body else { return }
        edit(body: SlackMarkdown.togglingCheckbox(in: body, line: line))
    }

    func openLink(title: String) {
        let wanted = title.lowercased()
        let target = try? repository.linkSuggestions(prefix: title, limit: 50).first { $0.title.lowercased() == wanted }
        if let id = target?.id { LibraryFeature.open(noteId: id) }
    }

    func updateLinkTrigger(text: String, cursor: Int) {
        linkTrigger = LinkTrigger.detect(in: text, cursor: cursor)
        let found = linkTrigger.flatMap { try? repository.linkSuggestions(prefix: $0.query, limit: 5) } ?? []
        suggestions = found.filter { $0.id != noteId }
        selectedSuggestion = 0
    }

    func dismissSuggestions() { linkTrigger = nil }

    func moveSuggestion(by step: Int) {
        guard suggestionRowCount > 0 else { return }
        selectedSuggestion = (selectedSuggestion + step + suggestionRowCount) % suggestionRowCount
    }

    /// Asks the text view to finish the link with the suggestion at `index`; the last row creates the note.
    func chooseSuggestion(at index: Int) {
        guard let trigger = linkTrigger else { return }
        var title = trigger.query
        if suggestions.indices.contains(index) {
            title = suggestions[index].title
        } else {
            var created = Note(body: trigger.query)
            do { try repository.save(&created, now: Date()) } catch { return report(error) }
        }
        completionRequest = LinkCompletion(range: trigger.range, text: title + "]]")
        linkTrigger = nil
    }

    // MARK: Footer

    func reloadFooter() {
        attachments = (try? attachmentStore.attachments(of: noteId)) ?? []
        backlinks = (try? repository.backlinks(to: noteId)) ?? []
        meeting = note?.sourceMeetingId.flatMap { try? meetings.meeting(id: $0) }
    }

    func fileURL(for attachment: Attachment) -> URL { attachmentStore.fileURL(for: attachment) }

    func remove(_ attachment: Attachment) {
        do { try attachmentStore.remove(attachment) } catch { report(error) }
        reloadFooter()
    }

    func importFiles(_ urls: [URL]) {
        Task {
            await AttachmentImporter.importFiles(urls, toNoteId: noteId)
            reloadFooter()
        }
    }

    /// Follows edits made elsewhere (Calendar sync, the edge) unless this editor has unsaved typing.
    func observeChanges() async {
        for await notes in database.noteChanges() {
            if !debouncer.hasPendingSave, let fresh = notes.first(where: { $0.id == noteId }),
                let current = note, fresh.updatedAt > current.updatedAt
            {
                note = fresh
                savedNote = fresh
            }
            reloadFooter()
        }
    }
}
