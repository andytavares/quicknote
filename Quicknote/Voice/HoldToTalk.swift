import Foundation
import QuicknoteKit

/// What the state machine needs from the rest of the app.
struct HoldToTalkServices {
    var ensurePermissions: () async -> Bool
    var frontmostContext: () async -> CapturedContext?
    var makeSession: () -> any SpeechSession
    var confirmEvent: (Int64) -> Void
    var repository: NoteRepository
    var now: () -> Date
    var calendar: Calendar

    static var live: HoldToTalkServices {
        HoldToTalkServices(
            ensurePermissions: {
                let hasMicrophone = await Permissions.ensure(.microphone)
                return hasMicrophone ? await Permissions.ensure(.speechRecognition) : false
            },
            frontmostContext: { await FrontmostContext.current() },
            makeSession: { MicrophoneSession() },
            confirmEvent: { CalendarConfirmation.present(forNoteId: $0) },
            repository: NoteRepository(database: AppEnvironment.current.database),
            now: { Date() },
            calendar: .current)
    }
}

/// The HUD, as the state machine sees it.
protocol HoldToTalkPresenting: AnyObject {
    func showPreparing()
    func showListening()
    func showFinishing()
    func showLive(text: String, chip: String?)
    func showLevel(_ level: Float)
    func showSaved(title: String, detail: String, undo: @escaping () -> Void)
    func showError(_ message: String)
    func hide()
}

/// idle → starting → listening → finishing → saved or cancelled. A key press is ignored unless a hold can begin.
final class HoldToTalk {
    enum State: Equatable {
        case idle, starting, listening, finishing, saved(noteId: Int64), cancelled
    }

    static let minimumHold: TimeInterval = 0.3

    private(set) var state = State.idle
    /// When set, the transcript on release goes here and no note is made.
    var captionTarget: ((String) -> Void)?

    private let services: HoldToTalkServices
    private let presenter: any HoldToTalkPresenting
    private var session: (any SpeechSession)?
    private var context: CapturedContext?
    private var pressedAt = Date.distantPast
    private var releasedEarly = false
    private var finishedText = ""
    private var work: Task<Void, Never>?

    init(services: HoldToTalkServices, presenter: any HoldToTalkPresenting) {
        self.services = services
        self.presenter = presenter
    }

    func keyDown() {
        switch state {
        case .idle, .saved, .cancelled:
            state = .starting
            pressedAt = services.now()
            releasedEarly = false
            work = Task { await begin() }
        case .starting, .listening, .finishing:
            break
        }
    }

    func keyUp() {
        switch state {
        case .starting:
            releasedEarly = true
        case .listening where services.now().timeIntervalSince(pressedAt) < Self.minimumHold:
            cancel()
        case .listening:
            state = .finishing
            presenter.showFinishing()
            work = Task { await finish() }
        default:
            break
        }
    }

    /// Waits for the work a key press started; for tests.
    func settled() async { await work?.value }

    // MARK: Starting

    private func begin() async {
        context = await services.frontmostContext()
        guard await services.ensurePermissions(), !releasedEarly else { return cancel() }
        presenter.showPreparing()
        let session = services.makeSession()
        self.session = session
        do { try await session.start() } catch { return fail(error) }
        guard !releasedEarly else { return cancel() }
        state = .listening
        finishedText = ""
        presenter.showListening()
        listen(to: session)
    }

    private func listen(to session: any SpeechSession) {
        Task { for await level in session.levels { presenter.showLevel(level) } }
        Task {
            var partial = ""
            for await update in session.updates {
                switch update {
                case .partial(let text): partial = text
                case .line(let line): (finishedText, partial) = (finishedText + " " + line.text, "")
                }
                showLive(finishedText + " " + partial)
            }
        }
    }

    private func showLive(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard state == .listening, !trimmed.isEmpty else { return }
        let note = VoiceNote.make(text: trimmed, now: services.now(), calendar: services.calendar)
        presenter.showLive(
            text: trimmed, chip: VoiceNote.chip(for: note, now: services.now(), calendar: services.calendar))
    }

    // MARK: Finishing

    private func finish() async {
        guard let session else { return cancel() }
        let lines: [SpokenLine]
        do { lines = try await session.finish() } catch { return fail(error) }
        self.session = nil
        let text = lines.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return cancel() }
        if let captionTarget {
            captionTarget(text)
            state = .idle
            presenter.hide()
        } else {
            save(text)
        }
    }

    private func save(_ text: String) {
        let now = services.now()
        var note = VoiceNote.make(text: text, now: now, calendar: services.calendar)
        note.remember(context)
        do { try services.repository.save(&note, now: now) } catch { return fail(error) }
        guard let noteId = note.id else { return cancel() }
        state = .saved(noteId: noteId)
        presenter.showSaved(
            title: note.title, detail: VoiceNote.chip(for: note, now: now, calendar: services.calendar),
            undo: { [weak self] in self?.undo(noteId: noteId) })
        if note.kind == .event { services.confirmEvent(noteId) }
    }

    private func undo(noteId: Int64) {
        try? services.repository.delete(noteId: noteId)
        presenter.hide()
    }

    // MARK: Stopping without a note

    private func cancel() {
        state = .cancelled
        presenter.hide()
        stopSession()
    }

    private func fail(_ error: any Error) {
        state = .cancelled
        presenter.showError(error.localizedDescription)
        stopSession()
    }

    private func stopSession() {
        let session = session
        self.session = nil
        work = Task { await session?.cancel() }
    }
}
