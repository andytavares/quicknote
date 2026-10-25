import AppKit
import QuicknoteKit

/// Writes a Card to its note: the canvas JSON, the photos as `.image` attachments and `preview.png`.
struct CardSaver {
    let repository: NoteRepository
    let attachments: AttachmentStore

    static var live: CardSaver {
        let environment = AppEnvironment.current
        return CardSaver(
            repository: NoteRepository(database: environment.database),
            attachments: AttachmentStore(paths: environment.paths, database: environment.database))
    }

    /// The first line of text on the card, so the Library can name it.
    static func body(of document: CanvasDocument, at time: Date) -> String {
        for element in document.elements {
            switch element.kind {
            case .text(let text), .extraNote(let text, _): if !text.isEmpty { return text }
            default: continue
            }
        }
        return "Card · \(time.formatted(date: .omitted, time: .shortened))"
    }

    /// Creates the note when `noteId` is nil; photos need a note to belong to before the first save.
    func ensureNote(_ noteId: Int64?, now: Date) throws -> Int64 {
        if let noteId { return noteId }
        var note = Note(body: "Card", now: now)
        try repository.save(&note, now: now)
        return note.id!
    }

    func attachPhoto(at url: URL, noteId: Int64) throws -> Attachment {
        try attachments.attach(fileAt: url, to: noteId, kind: .image)
    }

    func image(attachmentId: Int64, noteId: Int64) -> CGImage? {
        guard let attachment = try? attachments.attachments(of: noteId).first(where: { $0.id == attachmentId }),
            let source = CGImageSourceCreateWithURL(attachments.fileURL(for: attachment) as CFURL, nil)
        else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    func resources(noteId: Int64) -> CanvasResources {
        CanvasResources(
            image: { image(attachmentId: $0, noteId: noteId) }, paintBackground: CardBackgroundPainter.paint)
    }

    /// Returns the note id. The preview replaces the previous `preview.png`.
    func save(_ document: CanvasDocument, noteId: Int64?, now: Date) throws -> Int64 {
        let id = try ensureNote(noteId, now: now)
        var note = try repository.note(id: id) ?? Note(body: "", now: now)
        note.body = Self.body(of: document, at: note.createdAt)
        note.canvas = document
        try repository.save(&note, now: now)
        if let preview = CanvasRenderer.render(document, resources: resources(noteId: note.id!)) {
            try SnapSaver(repository: repository, attachments: attachments).replacePreview(preview, noteId: note.id!)
        }
        return note.id!
    }
}
