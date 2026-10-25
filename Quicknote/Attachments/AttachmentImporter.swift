import Foundation
import QuicknoteKit
import UniformTypeIdentifiers

/// Copies files into a note and reads text from images so they are searchable. Owned by the Capture unit.
enum AttachmentImporter {
    static func importFiles(_ urls: [URL], toNoteId noteId: Int64) async {
        let environment = AppEnvironment.current
        let store = AttachmentStore(paths: environment.paths, database: environment.database)
        await importFiles(urls, toNoteId: noteId, using: store)
    }

    /// A file that cannot be copied is skipped; the others still import.
    static func importFiles(_ urls: [URL], toNoteId noteId: Int64, using store: AttachmentStore) async {
        for url in urls {
            let isImage = UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) ?? false
            guard let attachment = try? store.attach(fileAt: url, to: noteId, kind: isImage ? .image : .file) else {
                continue
            }
            guard isImage, let attachmentId = attachment.id, let text = await ImageTextReader.text(inImageAt: url)
            else { continue }
            try? store.setExtractedText(text, for: attachmentId)
        }
    }
}
