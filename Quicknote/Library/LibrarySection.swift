import QuicknoteKit

/// One row of the Library sidebar (S10).
enum LibrarySection: Hashable {
    case brief, inbox, tasks, reminders, events, ideas, bookmarks, bugs, meetings, snaps, cards, sites, completed
    case project(Int64)

    /// Sidebar order between Daily Brief and Places.
    static let typeSections: [LibrarySection] = [
        .inbox, .tasks, .reminders, .events, .ideas, .bookmarks, .bugs, .meetings, .snaps, .cards,
    ]

    private static let kindSections: [LibrarySection] = [.tasks, .reminders, .events, .ideas, .bookmarks, .bugs]

    var title: String {
        switch self {
        case .brief: "Daily Brief"
        case .inbox: "Inbox"
        case .tasks: "Tasks"
        case .reminders: "Reminders"
        case .events: "Events"
        case .ideas: "Ideas"
        case .bookmarks: "Bookmarks"
        case .bugs: "Bugs"
        case .meetings: "Meetings"
        case .snaps: "Snaps"
        case .cards: "Cards"
        case .sites: "Sites and apps"
        case .completed: "Completed"
        case .project: "Project"
        }
    }

    var systemImage: String {
        switch self {
        case .brief: "sun.max"
        case .inbox: "tray"
        case .tasks: "checkmark.circle"
        case .reminders: "bell"
        case .events: "calendar"
        case .ideas: "lightbulb"
        case .bookmarks: "bookmark"
        case .bugs: "ladybug"
        case .meetings: "waveform"
        case .snaps: "camera.viewfinder"
        case .cards: "rectangle.on.rectangle"
        case .sites: "macwindow"
        case .completed: "checkmark.seal"
        case .project: "folder"
        }
    }

    /// The note type a section lists; nil for Inbox, Completed, projects and the views that are not note lists.
    var noteKind: NoteKind? {
        switch self {
        case .tasks: .task
        case .reminders: .reminder
        case .events: .event
        case .ideas: .idea
        case .bookmarks: .bookmark
        case .bugs: .bug
        default: nil
        }
    }

    /// The repository query behind the note list; nil for Daily Brief, Meetings, Snaps, Cards and Sites and apps.
    var filter: NoteListFilter? {
        switch self {
        case .inbox: .inbox
        case .completed: .completed
        case .project(let projectId): .project(projectId)
        default: noteKind.map(NoteListFilter.kind)
        }
    }

    /// Which gallery a section shows; nil for every other section.
    var galleryKind: GalleryKind? {
        switch self {
        case .snaps: .snap
        case .cards: .card
        default: nil
        }
    }

    /// Where `LibraryFeature.open(noteId:)` shows a note: Completed once done, else the section of its type.
    static func containing(_ note: Note) -> LibrarySection {
        if note.completedAt != nil { return .completed }
        return kindSections.first { $0.noteKind == note.kind } ?? .inbox
    }
}
