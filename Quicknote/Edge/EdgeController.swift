import AppKit
import QuicknoteKit

/// Owns the edge panels and keeps them in step with the database, the frontmost app and the screens.
final class EdgeController {
    static let shared = EdgeController()

    private let model = EdgeModel()
    private var panels: [EdgePanel] = []
    private var notes: [Note] = []
    private var panelsShowAllDisplays = true
    private var hideTask: Task<Void, Never>?

    func start() {
        let database = AppEnvironment.current.database
        let actions = EdgeActions(repository: NoteRepository(database: database))
        rebuildPanels(actions: actions)
        FrontmostTracker.shared.onChange = { [weak self] _ in self?.reload() }
        FrontmostTracker.shared.start()
        ReminderScheduler.shared.onFire = { [weak self] noteIds in self?.reveal(noteIds) }
        ReminderScheduler.shared.start(repository: actions.repository)
        Task { await observeScreens(actions: actions) }
        Task { await observeSettings(actions: actions) }
        Task { await observeNotes(database: database) }
    }

    func reload() {
        model.popsUpContextNotes = AppSettings.popsUpContextNotes
        model.update(notes: notes, context: FrontmostTracker.shared.context, now: Date())
        panels.forEach { $0.sync() }
    }

    func hide(for duration: Duration) {
        model.isHidden = true
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            model.isHidden = false
            reload()
        }
        reload()
    }

    private func reveal(_ noteIds: [Int64]) {
        reload()
        guard let noteId = noteIds.last, !model.isHidden else { return }
        model.reveal(noteId: noteId)
    }

    private func rebuildPanels(actions: EdgeActions) {
        panels.forEach { $0.close() }
        panelsShowAllDisplays = AppSettings.showsEdgeOnAllDisplays
        let screens =
            panelsShowAllDisplays ? NSScreen.screens : [NSScreen.main ?? NSScreen.screens.first].compactMap { $0 }
        panels = screens.map { EdgePanel(screen: $0, model: model, actions: actions) }
        reload()
    }

    private func observeNotes(database: AppDatabase) async {
        for await latest in database.noteChanges() {
            notes = latest
            reload()
            ReminderScheduler.shared.update(notes: latest)
        }
    }

    private func observeScreens(actions: EdgeActions) async {
        for await _ in NotificationCenter.default.notifications(
            named: NSApplication.didChangeScreenParametersNotification
        )
        .map({ _ in }) {
            rebuildPanels(actions: actions)
        }
    }

    private func observeSettings(actions: EdgeActions) async {
        for await _ in NotificationCenter.default.notifications(named: UserDefaults.didChangeNotification).map({ _ in })
        {
            if AppSettings.showsEdgeOnAllDisplays != panelsShowAllDisplays { rebuildPanels(actions: actions) }
            reload()
        }
    }
}
