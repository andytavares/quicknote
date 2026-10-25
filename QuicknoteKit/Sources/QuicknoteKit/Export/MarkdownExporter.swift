import Foundation
import GRDB

/// Writes notes as Markdown files with YAML front matter; attachments go in a folder named like the note.
public struct MarkdownExporter: Sendable {
    private let paths: AppPaths

    public init(paths: AppPaths) {
        self.paths = paths
    }

    public func export(_ note: Note, attachments: [Attachment], to folder: URL) throws -> URL {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let slug = uniqueSlug(for: note.title, in: folder)
        var text = Self.frontMatter(for: note) + note.body + "\n"
        if !attachments.isEmpty {
            let attachmentFolder = folder.appending(path: slug, directoryHint: .isDirectory)
            try fileManager.createDirectory(at: attachmentFolder, withIntermediateDirectories: true)
            text +=
                "\n" + (try copy(attachments, into: attachmentFolder, linkPrefix: slug)).joined(separator: "\n") + "\n"
        }
        let url = folder.appending(path: "\(slug).md")
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Returns how many notes were written.
    public func exportAll(database: AppDatabase, to folder: URL) throws -> Int {
        let (notes, attachments) = try database.writer.read { db in
            (try Note.order(Column("id")).fetchAll(db), try Attachment.order(Column("id")).fetchAll(db))
        }
        let attachmentsByNote = Dictionary(grouping: attachments, by: \.noteId)
        for note in notes {
            _ = try export(note, attachments: attachmentsByNote[note.id!] ?? [], to: folder)
        }
        return notes.count
    }

    private func copy(_ attachments: [Attachment], into folder: URL, linkPrefix: String) throws -> [String] {
        try attachments.map { attachment in
            var name = attachment.fileName
            if FileManager.default.fileExists(atPath: folder.appending(path: name).path) {
                name = "\(attachment.id ?? 0)-\(name)"
            }
            try FileManager.default.copyItem(
                at: paths.attachments.appending(path: attachment.relativePath), to: folder.appending(path: name))
            let target = "\(linkPrefix)/\(name)".addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
            return "\(attachment.kind == .image ? "!" : "")[\(attachment.fileName)](\(target))"
        }
    }

    private func uniqueSlug(for title: String, in folder: URL) -> String {
        let words = title.lowercased().split { !($0.isLetter || $0.isNumber) }.joined(separator: "-")
        let base = words.isEmpty ? "note" : String(words.prefix(60))
        var slug = base
        var suffix = 2
        while FileManager.default.fileExists(atPath: folder.appending(path: "\(slug).md").path)
            || FileManager.default.fileExists(atPath: folder.appending(path: slug).path)
        {
            slug = "\(base)-\(suffix)"
            suffix += 1
        }
        return slug
    }

    private static func frontMatter(for note: Note) -> String {
        let date = Date.ISO8601FormatStyle()
        let fields: [(String, String?)] = [
            ("kind", note.kind.rawValue),
            ("created", note.createdAt.formatted(date)),
            ("updated", note.updatedAt.formatted(date)),
            ("due", note.dueAt?.formatted(date)),
            ("recurrenceJSON", note.recurrenceJSON.map(quoted)),
            ("app", note.appName.map(quoted)),
            ("site", note.siteHost.map(quoted)),
            ("url", note.url.map(quoted)),
            ("project", note.projectId.map(String.init)),
        ]
        let lines = fields.compactMap { name, value in value.map { "\(name): \($0)" } }
        return (["---"] + lines + ["---", ""]).joined(separator: "\n") + "\n"
    }

    /// A JSON string is a valid YAML double-quoted scalar.
    private static func quoted(_ value: String) -> String {
        let data = try? JSONEncoder().encode(value)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
    }
}
