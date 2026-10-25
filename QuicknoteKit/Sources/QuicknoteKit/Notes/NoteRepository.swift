import Foundation
import GRDB

public enum NoteListFilter: Equatable, Sendable {
    /// Not completed, any kind except context.
    case inbox
    case kind(NoteKind)
    case project(Int64)
    case completed
}

/// Notes that belong to one site or app on the Sites and apps screen.
public struct ContextGroup: Equatable, Sendable {
    public var displayName: String
    public var appBundleId: String?
    public var siteHost: String?
    public var notes: [Note]
}

public struct NoteRepository: Sendable {
    private let database: AppDatabase

    public init(database: AppDatabase) { self.database = database }

    /// Inserts or updates the note, then rebuilds its `noteLink` rows from the `[[Title]]` links in its body.
    public func save(_ note: inout Note, now: Date) throws {
        note.updatedAt = now
        note = try database.writer.write { [note] db in
            var saved = note
            try saved.save(db)
            try rebuildLinks(for: saved, db)
            return saved
        }
    }

    public func delete(noteId: Int64) throws {
        _ = try database.writer.write { try Note.deleteOne($0, key: noteId) }
    }

    public func note(id: Int64) throws -> Note? {
        try database.writer.read { try Note.fetchOne($0, key: id) }
    }

    public func notes(matching filter: NoteListFilter) throws -> [Note] {
        try database.writer.read { db in
            try Self.request(for: filter)
                .order(sql: "dueAt IS NULL, dueAt, updatedAt DESC").fetchAll(db)
        }
    }

    public func backlinks(to noteId: Int64) throws -> [Note] {
        try database.writer.read { db in
            try Note.fetchAll(
                db,
                sql: """
                    SELECT note.* FROM note JOIN noteLink ON noteLink.fromNoteId = note.id
                    WHERE noteLink.toNoteId = ? ORDER BY note.updatedAt DESC
                    """, arguments: [noteId])
        }
    }

    /// Titles starting with `prefix` first, then titles containing it; case-insensitive.
    public func linkSuggestions(prefix: String, limit: Int) throws -> [Note] {
        let needle = prefix.lowercased()
        // shortcut: scans every note in memory (SQLite LIKE is ASCII-only), index titles if libraries grow past ~10k notes.
        let matching = try database.writer.read { try Note.fetchAll($0) }
            .filter { $0.title.lowercased().contains(needle) }
        let (starting, containing) = (
            matching.filter { $0.title.lowercased().hasPrefix(needle) },
            matching.filter { !$0.title.lowercased().hasPrefix(needle) }
        )
        return Array((starting + containing).prefix(limit))
    }

    /// Notes with an app or site, grouped by site host when present, else by app.
    public func contextGroups() throws -> [ContextGroup] {
        let notes = try database.writer.read { db in
            try Note.filter(Column("siteHost") != nil || Column("appBundleId") != nil)
                .order(sql: "updatedAt DESC").fetchAll(db)
        }
        let grouped = Dictionary(grouping: notes) { $0.siteHost ?? $0.appBundleId ?? "" }
        return grouped.values.map(Self.group).sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    private static func group(_ notes: [Note]) -> ContextGroup {
        let first = notes[0]
        if let host = first.siteHost {
            return ContextGroup(displayName: host, appBundleId: nil, siteHost: host, notes: notes)
        }
        let name = notes.lazy.compactMap(\.appName).first ?? first.appBundleId ?? ""
        return ContextGroup(displayName: name, appBundleId: first.appBundleId, siteHost: nil, notes: notes)
    }

    private static func request(for filter: NoteListFilter) -> QueryInterfaceRequest<Note> {
        let open = Note.filter(Column("completedAt") == nil)
        switch filter {
        case .inbox: return open.filter(Column("kind") != NoteKind.context)
        case .kind(let kind): return open.filter(Column("kind") == kind)
        case .project(let projectId): return open.filter(Column("projectId") == projectId)
        case .completed: return Note.filter(Column("completedAt") != nil)
        }
    }

    /// Rebuilds links from this note and links to it, so renames and late-created targets stay linked.
    private func rebuildLinks(for note: Note, _ db: Database) throws {
        guard let noteId = note.id else { return }
        try NoteLink.filter(Column("fromNoteId") == noteId || Column("toNoteId") == noteId).deleteAll(db)
        let wanted = Set(NoteLinkParser.linkedTitles(in: note.body).map { $0.lowercased() })
        let ownTitle = note.title.lowercased()
        // shortcut: loads every note body to match titles, fine for a personal library.
        let rows = try Row.fetchAll(db, sql: "SELECT id, body FROM note WHERE id != ?", arguments: [noteId])
        for row in rows {
            let other: Int64 = row["id"]
            let body: String = row["body"]
            if wanted.contains(Note(body: body).title.lowercased()) {
                try NoteLink(fromNoteId: noteId, toNoteId: other).insert(db)
            }
            if NoteLinkParser.linkedTitles(in: body).contains(where: { $0.lowercased() == ownTitle }) {
                try NoteLink(fromNoteId: other, toNoteId: noteId).insert(db)
            }
        }
    }
}
