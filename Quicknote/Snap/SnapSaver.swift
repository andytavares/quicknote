import AppKit
import QuicknoteKit

/// A Snap being saved: the captured image and the markup drawn on it.
struct SnapContent {
    let original: CGImage
    let document: CanvasDocument
}

/// Writes a Snap to the database: the note, the original image, the canvas JSON and `preview.png`.
struct SnapSaver {
    static let previewFileName = "preview.png"

    let repository: NoteRepository
    let attachments: AttachmentStore

    static var live: SnapSaver {
        let environment = AppEnvironment.current
        return SnapSaver(
            repository: NoteRepository(database: environment.database),
            attachments: AttachmentStore(paths: environment.paths, database: environment.database))
    }

    static func body(caption: String?, at time: Date) -> String {
        if let caption, !caption.isEmpty { return caption }
        return "Snap · \(time.formatted(date: .omitted, time: .shortened))"
    }

    /// Creates the note when `noteId` is nil, otherwise updates it. Returns the note id.
    func save(_ content: SnapContent, noteId: Int64?, now: Date) async throws -> Int64 {
        let (original, document) = (content.original, content.document)
        var note = try noteId.flatMap { try repository.note(id: $0) } ?? Note(body: "", now: now)
        note.body = Self.body(caption: document.caption, at: note.createdAt)
        try repository.save(&note, now: now)
        let id = note.id!
        let originalId = try await originalAttachmentId(of: id, image: original)
        var finished = document
        finished.background = .image(attachmentId: originalId, size: CanvasRenderer.pixelSize(of: document))
        note.canvas = finished
        try repository.save(&note, now: now)
        let resources = CanvasResources(image: { _ in original })
        if let preview = CanvasRenderer.render(finished, resources: resources) {
            try replacePreview(preview, noteId: id)
        }
        return id
    }

    /// A note keeps exactly one `preview.png`; the old one is removed.
    func replacePreview(_ image: CGImage, noteId: Int64) throws {
        for old in try attachments.attachments(of: noteId)
        where old.kind == .snap && old.fileName == Self.previewFileName {
            try attachments.remove(old)
        }
        let url = try Self.write(image, named: Self.previewFileName)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        _ = try attachments.attach(fileAt: url, to: noteId, kind: .snap)
    }

    private func originalAttachmentId(of noteId: Int64, image: CGImage) async throws -> Int64 {
        if let existing = try attachments.attachments(of: noteId).first(where: { $0.kind == .image }) {
            return existing.id!
        }
        let url = try Self.write(image, named: "snap.png")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let attachment = try attachments.attach(fileAt: url, to: noteId, kind: .image)
        let stored = attachments.fileURL(for: attachment)
        if let text = await ImageTextReader.text(inImageAt: stored), !text.isEmpty {
            try attachments.setExtractedText(text, for: attachment.id!)
        }
        return attachment.id!
    }

    /// `AttachmentStore.attach` names the stored file after the source, so each file gets its own folder.
    private static func write(_ image: CGImage, named name: String) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: name)
        guard let data = image.pngData else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: url)
        return url
    }
}
