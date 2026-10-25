import Foundation
import Observation
import QuicknoteKit

/// What the Library window shows. `observe()` keeps it in step with the database.
@Observable
final class LibraryModel {
    var section: LibrarySection = .inbox {
        didSet { if section != oldValue { reload() } }
    }
    var selection: Set<Int64> = []
    var grouping: TaskGrouping = .dueDate
    var pendingDeletion: Set<Int64> = []

    private(set) var listNotes: [Note] = []
    private(set) var galleryNotes: [Note] = []
    private(set) var counts: [LibrarySection: Int] = [:]
    private(set) var projects: [Project] = []
    private(set) var meetings: [Meeting] = []
    private(set) var contextGroups: [ContextGroup] = []
    private(set) var previewURLs: [Int64: URL] = [:]
    private var allNotes: [Note] = []

    let database: AppDatabase
    private let paths: AppPaths

    init(database: AppDatabase, paths: AppPaths) {
        self.database = database
        self.paths = paths
        reload()
    }

    /// The note in the editor pane: the selection when exactly one note is selected.
    var openNoteId: Int64? { selection.count == 1 ? selection.first : nil }

    var notes: NoteRepository { NoteRepository(database: database) }
    var projectRepository: ProjectRepository { ProjectRepository(database: database) }

    /// Runs until the window's view goes away.
    func observe() async {
        for await latest in database.noteChanges() {
            allNotes = latest
            reload()
        }
    }

    func reload() {
        projects = (try? projectRepository.all()) ?? []
        meetings = (try? MeetingRepository(database: database).all()) ?? []
        listNotes = section.filter.flatMap { try? notes.notes(matching: $0) } ?? []
        selection.formIntersection(Set(listNotes.compactMap(\.id)))
        reloadGallery()
        reloadCounts()
        if section == .sites { contextGroups = (try? notes.contextGroups()) ?? [] }
    }

    private func reloadGallery() {
        galleryNotes = allNotes.filter { section.galleryKind != nil && GalleryKind.classify($0) == section.galleryKind }
            .sorted { $0.createdAt > $1.createdAt }
        let store = AttachmentStore(paths: paths, database: database)
        previewURLs = Dictionary(
            uniqueKeysWithValues: galleryNotes.compactMap { note in
                guard let noteId = note.id else { return nil }
                let preview = (try? store.attachments(of: noteId))?.last {
                    $0.kind == .snap && $0.fileName == "preview.png"
                }
                return preview.map { (noteId, store.fileURL(for: $0)) }
            })
    }

    private func reloadCounts() {
        var counts: [LibrarySection: Int] = [.meetings: meetings.count]
        for section in LibrarySection.typeSections {
            if let filter = section.filter { counts[section] = (try? notes.notes(matching: filter).count) ?? 0 }
        }
        counts[.snaps] = allNotes.filter { GalleryKind.classify($0) == .snap }.count
        counts[.cards] = allNotes.filter { GalleryKind.classify($0) == .card }.count
        let projectCounts = (try? projectRepository.noteCounts()) ?? [:]
        for (projectId, count) in projectCounts { counts[.project(projectId)] = count }
        self.counts = counts
    }
}
